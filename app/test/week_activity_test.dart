import 'package:flutter_test/flutter_test.dart';
import 'package:shared_space_app/features/calendar/week_activity.dart';

String iso(DateTime local) => local.toUtc().toIso8601String();

Map<String, dynamic> entry({
  required DateTime localCreated,
  required String author,
}) =>
    {'created_at': iso(localCreated), 'author_id': author};

void main() {
  test('WEEK-001 时间桶 + 不同成员去重（TEST_PLAN 示例）', () {
    final weekStart = DateTime(2026, 8, 10); // 周一
    final entries = [
      entry(localCreated: DateTime(2026, 8, 10, 10, 20), author: 'a'),
      entry(localCreated: DateTime(2026, 8, 10, 10, 40), author: 'b'),
      entry(localCreated: DateTime(2026, 8, 10, 10, 45), author: 'b'),
      entry(localCreated: DateTime(2026, 8, 10, 14, 20), author: 'a'),
    ];
    final activity = calculateWeeklyActivity(entries, weekStart: weekStart);

    expect(activity.days.length, 7, reason: '周视图必须包含 7 天');
    expect(activity.days.first, DateTime(2026, 8, 10), reason: '周一起始');
    expect(activity.days.last, DateTime(2026, 8, 16));
    expect(activity.counts[0].length, WeekActivity.bucketCount);

    expect(activity.counts[0][10 - WeekActivity.firstHour], 2,
        reason: '10:00 桶 → A、B 两人（不是 3 条记录）');
    expect(activity.counts[0][14 - WeekActivity.firstHour], 1);
  });

  test('小时桶边界：08:00 与 23:00 计入，07:59/00:00 忽略', () {
    final weekStart = DateTime(2026, 8, 10);
    final entries = [
      entry(localCreated: DateTime(2026, 8, 10, 7, 59), author: 'a'),
      entry(localCreated: DateTime(2026, 8, 10, 8, 0), author: 'b'),
      entry(localCreated: DateTime(2026, 8, 10, 23, 59), author: 'c'),
      entry(localCreated: DateTime(2026, 8, 11, 0, 0), author: 'd'),
    ];
    final activity = calculateWeeklyActivity(entries, weekStart: weekStart);
    expect(activity.counts[0][0], 1, reason: '08:00 桶只有 b');
    expect(activity.counts[0][WeekActivity.bucketCount - 1], 1,
        reason: '23:00 桶只有 c');
    expect(activity.counts[0].sum(), 2, reason: '07:59 被忽略');
    expect(activity.counts[1].sum(), 0, reason: '00:00 被忽略');
  });

  test('跨周边界：上周日不计入，本周一计入', () {
    final weekStart = DateTime(2026, 8, 10); // 周一
    final entries = [
      entry(localCreated: DateTime(2026, 8, 9, 12, 0), author: 'a'), // 上周日
      entry(localCreated: DateTime(2026, 8, 10, 0, 1), author: 'b'), // 周一
      entry(localCreated: DateTime(2026, 8, 16, 23, 0), author: 'c'), // 周日
    ];
    final activity = calculateWeeklyActivity(entries, weekStart: weekStart);
    // 周一 00:01 落在 0 点桶 → 被忽略（显示范围 08:00 起）
    expect(activity.counts[0].sum(), 0);
    expect(activity.counts[6][WeekActivity.bucketCount - 1], 1);
  });

  test('WEEK-002 时间区间标签表达区间而不是单个刻度点', () {
    expect(weekHourIntervalLabel(8), '08:00–09:00');
    expect(weekHourIntervalLabel(22), '22:00–23:00');
    expect(weekHourIntervalLabel(23), '23:00–24:00');
  });

  test('缺失字段的行被忽略，不崩溃', () {
    final weekStart = DateTime(2026, 8, 10);
    final activity = calculateWeeklyActivity(
      [<String, dynamic>{}, {'created_at': 123, 'author_id': 'a'}],
      weekStart: weekStart,
    );
    expect(activity.counts.every((row) => row.every((c) => c == 0)), isTrue);
  });
}

extension on List<int> {
  int sum() => fold(0, (a, b) => a + b);
}
