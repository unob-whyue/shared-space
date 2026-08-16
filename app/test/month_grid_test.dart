import 'package:flutter_test/flutter_test.dart';
import 'package:shared_space_app/features/calendar/month_grid.dart';

void main() {
  test('2026-08 网格：周一起始、42 格、含前后月补位', () {
    final cells = monthGridDates(2026, 8);
    expect(cells.length, 42);
    expect(cells.first.weekday, DateTime.monday);
    expect(cells.first, DateTime(2026, 7, 27)); // 2026-08-01 是周六
    expect(cells.contains(DateTime(2026, 8, 1)), isTrue);
    expect(cells.contains(DateTime(2026, 8, 31)), isTrue);
    expect(cells.last, DateTime(2026, 9, 6));
  });

  test('2026-02（28 天）网格', () {
    final cells = monthGridDates(2026, 2);
    expect(cells.length, 42);
    expect(cells.first, DateTime(2026, 1, 26)); // 2026-02-01 是周日
    expect(cells.last, DateTime(2026, 3, 8));
  });

  test('相邻月份网格：九月起始为八月最后一行的周一', () {
    final aug = monthGridDates(2026, 8);
    final sep = monthGridDates(2026, 9);
    expect(sep.first, DateTime(2026, 8, 31)); // 9/1 是周二 → 补位周一
    expect(sep.first.weekday, DateTime.monday);
    expect(aug.last, DateTime(2026, 9, 6));
  });
}
