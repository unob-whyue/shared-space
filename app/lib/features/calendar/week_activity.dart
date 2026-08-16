// 周视图计算（API_SERVICE.md §13/§14）：
// 纯函数，不建 WeeklyActivityService / StatisticsService。
// 输入为 getByDateRange() 返回的日记行（含 created_at / author_id）。

/// 周一 00:00。
DateTime mondayOf(DateTime d) {
  final date = DateTime(d.year, d.month, d.day);
  return date.subtract(Duration(days: date.weekday - 1));
}

/// 一周活动密度：7 天 × 小时桶（08:00–23:00，共 16 桶）。
/// 每格 = 该日期该小时「不同成员」数量（同一成员同一小时多篇只计 1）。
class WeekActivity {
  WeekActivity({required this.days, required this.counts});

  static const int firstHour = 8;
  static const int lastHour = 23;
  static const int bucketCount = lastHour - firstHour + 1;

  /// 周一..周日（7 天）。
  final List<DateTime> days;

  /// counts[dayIndex][hourIndex] = 不同成员数；hourIndex 0 ↔ 08:00。
  final List<List<int>> counts;
}

WeekActivity calculateWeeklyActivity(
  List<Map<String, dynamic>> entries, {
  required DateTime weekStart,
}) {
  final start = mondayOf(weekStart);
  final days =
      List.generate(7, (i) => DateTime(start.year, start.month, start.day + i));
  final membersPerBucket = List.generate(
    7,
    (_) => List.generate(
      WeekActivity.bucketCount,
      (_) => <String>{},
    ),
  );

  for (final entry in entries) {
    final createdAtRaw = entry['created_at'];
    final authorId = entry['author_id'];
    if (createdAtRaw is! String || authorId is! String) continue;
    final created = DateTime.parse(createdAtRaw).toLocal();
    // 按日历日计算（不能用 created.difference(start).inDays：
    // 负小数天数会截断为 0，把上周日错算进周一列）。
    final createdDate = DateTime(created.year, created.month, created.day);
    final dayIndex = createdDate.difference(start).inDays;
    if (dayIndex < 0 || dayIndex > 6) continue;
    final hour = created.hour;
    if (hour < WeekActivity.firstHour || hour > WeekActivity.lastHour) {
      continue;
    }
    membersPerBucket[dayIndex][hour - WeekActivity.firstHour].add(authorId);
  }

  final counts = membersPerBucket
      .map((row) => row.map((set) => set.length).toList())
      .toList();
  return WeekActivity(days: days, counts: counts);
}
