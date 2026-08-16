/// 月视图网格（纯函数）：周一起始的 6×7 网格，含前后月补位日期。
/// 仅解决「哪些日期有记录」的标记定位，不放任何内容进格子。
List<DateTime> monthGridDates(int year, int month) {
  final first = DateTime(year, month, 1);
  final offset = first.weekday - 1; // DateTime.weekday: 周一=1
  final start = first.subtract(Duration(days: offset));
  return List.generate(
    42,
    (i) => DateTime(start.year, start.month, start.day + i),
  );
}
