import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';

/// 批注通知实时变更事件。
class NotificationChange {
  const NotificationChange({
    required this.eventType,
    required this.newRow,
    required this.oldRow,
  });

  final String eventType;
  final Map<String, dynamic> newRow;
  final Map<String, dynamic> oldRow;
}

/// notifications 数据访问（V1.1 App 内部通知）。
/// 客户端只允许读取 / 标记已读；通知由数据库 trigger 生成。
class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  static const int _pageSize = 1000;

  Future<List<Map<String, dynamic>>> getMyNotifications() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AppError('未登录');
    return _fetchAll((start, end) async {
      return await _client
          .from('notifications')
          .select(
            '*, '
            'actor:profiles!notifications_actor_user_id_fkey(nickname, color), '
            'diary:diary_entries!notifications_diary_id_fkey(space_id, diary_date), '
            'annotation:diary_annotations!notifications_annotation_id_fkey(selected_text, comment)',
          )
          .eq('recipient_user_id', uid)
          .order('created_at', ascending: false)
          .range(start, end);
    });
  }

  /// 未读数：分页读取 read_at 并本地计数，避免依赖特定 null 过滤 API。
  Future<int> unreadCount() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AppError('未登录');
    var count = 0;
    var start = 0;
    while (true) {
      final rows = await _client
          .from('notifications')
          .select('read_at')
          .eq('recipient_user_id', uid)
          .range(start, start + _pageSize - 1);
      count += rows.where((r) => r['read_at'] == null).length;
      if (rows.length < _pageSize) break;
      start += _pageSize;
    }
    return count;
  }

  Future<void> markRead(String id) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AppError('未登录');
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('recipient_user_id', uid);
  }

  Future<void> markAllRead() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AppError('未登录');
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('recipient_user_id', uid);
  }

  /// 监听发给当前用户的通知变更（订阅 → ready → 快照模式同 Diary）。
  ({Stream<NotificationChange> stream, Future<void> ready})
      watchMyNotifications() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      final controller = StreamController<NotificationChange>.broadcast();
      final joined = Completer<void>();
      joined.completeError(const AppError('未登录'));
      controller.onCancel = () => controller.close();
      return (stream: controller.stream, ready: joined.future);
    }

    final channel = _client.channel(
      'notif-$uid-${DateTime.now().microsecondsSinceEpoch}',
    );
    final controller = StreamController<NotificationChange>.broadcast();
    final joined = Completer<void>();

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_user_id',
            value: uid,
          ),
          callback: (payload) {
            controller.add(NotificationChange(
              eventType: payload.eventType.name,
              newRow: payload.newRecord,
              oldRow: payload.oldRecord,
            ));
          },
        )
        .subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed &&
          !joined.isCompleted) {
        joined.complete();
      }
    });

    controller.onCancel = () {
      unawaited(channel.unsubscribe());
      unawaited(_client.removeChannel(channel));
      unawaited(controller.close());
    };
    return (stream: controller.stream, ready: joined.future);
  }

  Future<List<Map<String, dynamic>>> _fetchAll(
    Future<List<Map<String, dynamic>>> Function(int start, int end) fetch,
  ) async {
    final all = <Map<String, dynamic>>[];
    var start = 0;
    while (true) {
      final rows = await fetch(start, start + _pageSize - 1);
      all.addAll(rows);
      if (rows.length < _pageSize) break;
      start += _pageSize;
    }
    return all;
  }
}
