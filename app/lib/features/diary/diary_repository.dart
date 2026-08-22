import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import 'diary_image_repository.dart';

/// 日记日期格式化（diary_date 为 date 类型，存储格式 YYYY-MM-DD）。
String formatDiaryDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Realtime 变更事件（DIARY 的 INSERT/UPDATE/DELETE）。
class DiaryChange {
  const DiaryChange({
    required this.eventType,
    required this.newRow,
    required this.oldRow,
  });

  final String eventType;
  final Map<String, dynamic> newRow;
  final Map<String, dynamic> oldRow;
}

/// diary_entries 数据访问（API_SERVICE.md §8）。
class DiaryRepository {
  DiaryRepository(this._client);

  final SupabaseClient _client;

  /// 创建日记：服务端确定 author_id / created_at / updated_at（DB trigger）。
  Future<Map<String, dynamic>> createDiary({
    required String spaceId,
    required DateTime diaryDate,
    required String content,
    required String weather,
    required String mood,
  }) async {
    final row = await _client
        .from('diary_entries')
        .insert({
          'space_id': spaceId,
          'diary_date': formatDiaryDate(diaryDate),
          'content': content,
          'weather': weather,
          'mood': mood,
        })
        .select()
        .single();
    return row;
  }

  Future<Map<String, dynamic>> getDiary(String id) async {
    return await _client
        .from('diary_entries')
        .select('*, profiles(nickname, color)')
        .eq('id', id)
        .single();
  }

  /// 修改日记：只允许 diaryDate / content / weather / mood。
  Future<Map<String, dynamic>> updateDiary(
    String id, {
    String? diaryDate,
    String? content,
    String? weather,
    String? mood,
  }) async {
    final updates = <String, dynamic>{
      'diary_date': ?diaryDate,
      'content': ?content,
      'weather': ?weather,
      'mood': ?mood,
    };
    final row = await _client
        .from('diary_entries')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return row;
  }

  /// 删除日记（API_SERVICE.md §11）。
  /// 顺序约束（见 002 migration）：Storage 删除策略校验「路径指向的
  /// Diary 属于当前用户」，要求 diary 行仍存在 —— 因此必须先清理
  /// Storage 对象，再删除 diary 行（行删除级联 Images/Annotations）。
  /// 非作者调用时：对象删除被 Storage 策略拒绝（捕获忽略）、行删除被
  /// RLS 静默拒绝（0 行），数据不受影响。
  Future<void> deleteDiary(String id) async {
    final images = await _client
        .from('diary_images')
        .select('storage_path')
        .eq('diary_id', id);
    final paths = images.map((r) => r['storage_path'] as String).toList();
    if (paths.isNotEmpty) {
      try {
        await _client.storage.from(kDiaryImagesBucket).remove(paths);
      } catch (_) {}
    }
    await _client.from('diary_entries').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getByDate(String spaceId, DateTime date) =>
      getByDateRange(spaceId, date, date);

  /// 一次获取区间数据（月视图 / 周视图用，不发 30 次请求）。
  /// 分页拉取全部行，避免 PostgREST 默认 max-rows 截断导致日记悄悄丢失。
  Future<List<Map<String, dynamic>>> getByDateRange(
    String spaceId,
    DateTime from,
    DateTime to,
  ) async {
    return _fetchAll((start, end) async {
      return await _client
          .from('diary_entries')
          .select('*, profiles(nickname, color), diary_images(id)')
          .eq('space_id', spaceId)
          .gte('diary_date', formatDiaryDate(from))
          .lte('diary_date', formatDiaryDate(to))
          .order('created_at', ascending: true)
          .range(start, end);
    });
  }

  /// 按 created_at 区间获取日记（周视图时间桶点击使用）。
  /// 与 calculateWeeklyActivity 使用同一时间口径，避免与 diary_date 口径
  /// 不一致造成部分日记在时间桶详情中不可见。
  Future<List<Map<String, dynamic>>> getByCreatedAtRange(
    String spaceId,
    DateTime from,
    DateTime to,
  ) async {
    return _fetchAll((start, end) async {
      return await _client
          .from('diary_entries')
          .select('*, profiles(nickname, color), diary_images(id)')
          .eq('space_id', spaceId)
          .gte('created_at', from.toUtc().toIso8601String())
          .lte('created_at', to.toUtc().toIso8601String())
          .order('created_at', ascending: true)
          .range(start, end);
    });
  }

  /// 我的记录：同一 DiaryEntry 的个人视图，不是第二份数据。
  Future<List<Map<String, dynamic>>> getMyDiaries() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AppError('未登录');
    return _fetchAll((start, end) async {
      return await _client
          .from('diary_entries')
          .select()
          .eq('author_id', uid)
          .order('diary_date', ascending: false)
          .range(start, end);
    });
  }

  static const int _pageSize = 1000;

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

  /// 监听指定空间日记的实时变更（REALTIME）。
  ///
  /// 返回 [ready]：Realtime channel 完成 join 的 Future。
  /// join 窗口期内发生的事件不会补发（Supabase Realtime 语义），
  /// 因此页面初始化的正确时序是「先建立订阅并确认 ready → 再获取全量快照」：
  /// 快照会补回窗口期内的事件；ready 之后的事件由调用方处理，
  /// 且必须防止与快照并发产生重复数据（见 space_detail_page 的代际收敛）。
  ({Stream<DiaryChange> stream, Future<void> ready}) watchDiaryChanges(
      String spaceId) {
    final channel = _client.channel(
      'diary-$spaceId-${DateTime.now().microsecondsSinceEpoch}',
    );
    final controller = StreamController<DiaryChange>.broadcast();
    final joined = Completer<void>();

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'diary_entries',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'space_id',
            value: spaceId,
          ),
          callback: (payload) {
            controller.add(DiaryChange(
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
      // 非阻塞清理：unsubscribe/removeChannel 在部分版本可能迟迟不完成，
      // 不 await（避免测试与页面退出被挂住）。
      unawaited(channel.unsubscribe());
      unawaited(_client.removeChannel(channel));
      unawaited(controller.close());
    };
    return (stream: controller.stream, ready: joined.future);
  }
}
