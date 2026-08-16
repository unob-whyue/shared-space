import 'package:flutter_test/flutter_test.dart';
import 'package:shared_space_app/features/calendar/week_activity.dart';
import 'package:shared_space_app/features/diary/diary_repository.dart';
import 'package:shared_space_app/features/space/space_repository.dart';
import 'package:shared_space_app/features/space/space_service.dart';

import 'spike/spike_support.dart';

/// V1 Milestone 3（视图）真实环境集成测试。
/// 前置：Supabase 已应用 001/002 migration。
///
/// 运行：
///   flutter test test/milestone3_test.dart \
///     --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
void main() {
  late TestAccount userA;
  late TestAccount userB;
  late Map<String, dynamic> space;

  setUpAll(() async {
    if (!SpikeEnv.isConfigured) {
      fail('未配置连接信息：请通过 --dart-define=SUPABASE_URL=... / '
          'SUPABASE_ANON_KEY=... 运行，或设置同名环境变量。');
    }
    userA = await TestAccount.register('m3a', admin: null);
    userB = await TestAccount.register('m3b', admin: null);
    space = await SpaceRepository(userA.client).createSpace('里程碑三空间');
    await SpaceService(SpaceRepository(userB.client))
        .joinByInviteCode(space['invite_code'] as String);
  });

  test('MONTH-001 月视图数据：当月有记录的日期集合正确', () async {
    final repo = DiaryRepository(userA.client);
    final now = DateTime.now();
    final d1 = DateTime(now.year, now.month, 5);
    final d2 = DateTime(now.year, now.month, 15);
    await repo.createDiary(
      spaceId: space['id'] as String,
      diaryDate: d1,
      content: '五日',
      weather: 'sunny',
      mood: 'happy',
    );
    await DiaryRepository(userB.client).createDiary(
      spaceId: space['id'] as String,
      diaryDate: d2,
      content: '十五日',
      weather: 'rain',
      mood: 'calm',
    );

    final monthRows = await repo.getByDateRange(
      space['id'] as String,
      DateTime(now.year, now.month, 1),
      DateTime(now.year, now.month + 1, 0),
    );
    final dates = monthRows.map((r) => r['diary_date'] as String).toSet();
    expect(dates.contains(formatDiaryDate(d1)), isTrue);
    expect(dates.contains(formatDiaryDate(d2)), isTrue);

    // 上月区间无这两条
    final prevRows = await repo.getByDateRange(
      space['id'] as String,
      DateTime(now.year, now.month - 1, 1),
      DateTime(now.year, now.month, 0),
    );
    expect(
      prevRows.any((r) =>
          r['diary_date'] == formatDiaryDate(d1) ||
          r['diary_date'] == formatDiaryDate(d2)),
      isFalse,
    );
  });

  test('DAY-001 当日多成员日记：只含该日且 created_at ASC', () async {
    final day = DateTime.now().subtract(const Duration(days: 3));
    final dA = await DiaryRepository(userA.client).createDiary(
      spaceId: space['id'] as String,
      diaryDate: day,
      content: 'A 的当日',
      weather: 'sunny',
      mood: 'happy',
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final dB = await DiaryRepository(userB.client).createDiary(
      spaceId: space['id'] as String,
      diaryDate: day,
      content: 'B 的当日',
      weather: 'cloudy',
      mood: 'calm',
    );

    final rows = await DiaryRepository(userA.client)
        .getByDate(space['id'] as String, day);
    expect(rows.every((r) => r['diary_date'] == formatDiaryDate(day)), isTrue);
    expect(rows.length, 2);
    expect(rows.first['id'], dA['id'], reason: 'A 先创建 → 排在前');
    expect(rows.last['id'], dB['id']);
  });

  test('WEEK-001 数据流：本周区间包含刚创建的日记', () async {
    final repo = DiaryRepository(userA.client);
    final created = await repo.createDiary(
      spaceId: space['id'] as String,
      diaryDate: DateTime.now(),
      content: '本周数据流',
      weather: 'sunny',
      mood: 'happy',
    );
    final start = mondayOf(DateTime.now());
    final rows = await repo.getByDateRange(
      space['id'] as String,
      start,
      start.add(const Duration(days: 6)),
    );
    expect(rows.any((r) => r['id'] == created['id']), isTrue);
    // 周视图纯函数可正常计算（时间桶逻辑由 week_activity_test 覆盖）
    final activity = calculateWeeklyActivity(rows, weekStart: start);
    expect(activity.days.length, 7);
  });

  test('MY-001 我的记录：只含当前用户，与共享数据同一 DiaryEntry', () async {
    final repo = DiaryRepository(userA.client);
    final mine = await repo.getMyDiaries();
    expect(mine.every((m) => m['author_id'] == userA.userId), isTrue,
        reason: '我的记录不能出现别人的日记');

    // 共享视图中 A 的日记必须与「我的记录」是同一批行（同一 id，非副本）
    final now = DateTime.now();
    final shared = await repo.getByDateRange(
      space['id'] as String,
      DateTime(now.year, now.month - 1, 1),
      DateTime(now.year, now.month + 1, 0),
    );
    final mineIds = mine.map((m) => m['id']).toSet();
    final aInShared =
        shared.where((r) => r['author_id'] == userA.userId).toList();
    expect(aInShared, isNotEmpty);
    expect(aInShared.every((r) => mineIds.contains(r['id'])), isTrue,
        reason: '共享日记与我的记录必须共用同一 DiaryEntry');
  });
}
