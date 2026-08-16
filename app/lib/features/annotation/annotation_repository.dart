import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Realtime 批注变更事件。
class AnnotationChange {
  const AnnotationChange({
    required this.eventType,
    required this.newRow,
    required this.oldRow,
  });

  final String eventType;
  final Map<String, dynamic> newRow;
  final Map<String, dynamic> oldRow;
}

/// diary_annotations 数据访问（API_SERVICE.md §17）。
/// V1 只支持 create / getByDiary / watchChanges；
/// 不实现 update / delete / reply / thread，不建 AnnotationService。
class AnnotationRepository {
  AnnotationRepository(this._client);

  final SupabaseClient _client;

  /// 创建批注：author_id / created_at 由服务器 trigger 确定。
  Future<Map<String, dynamic>> create({
    required String diaryId,
    required int startOffset,
    required int endOffset,
    required String selectedText,
    required String comment,
  }) async {
    final row = await _client
        .from('diary_annotations')
        .insert({
          'diary_id': diaryId,
          'start_offset': startOffset,
          'end_offset': endOffset,
          'selected_text': selectedText,
          'comment': comment,
        })
        .select('*, profiles(nickname, color)')
        .single();
    return row;
  }

  /// 读取一篇日记的全部批注（页面负责与原文选区关联）。
  Future<List<Map<String, dynamic>>> getByDiary(String diaryId) async {
    return await _client
        .from('diary_annotations')
        .select('*, profiles(nickname, color)')
        .eq('diary_id', diaryId)
        .order('created_at');
  }

  /// 监听该日记的批注实时变更（订阅 → ready → 快照模式同 Diary）。
  ({Stream<AnnotationChange> stream, Future<void> ready}) watchChanges(
      String diaryId) {
    final channel = _client.channel(
      'anno-$diaryId-${DateTime.now().microsecondsSinceEpoch}',
    );
    final controller = StreamController<AnnotationChange>.broadcast();
    final joined = Completer<void>();

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'diary_annotations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'diary_id',
            value: diaryId,
          ),
          callback: (payload) {
            controller.add(AnnotationChange(
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
}
