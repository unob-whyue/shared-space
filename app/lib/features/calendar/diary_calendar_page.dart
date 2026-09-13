import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_kit.dart';
import '../../core/app_tokens.dart';
import '../diary/diary_editor_page.dart';
import '../diary/diary_repository.dart';
import 'day_diaries_page.dart';
import 'hour_diaries_page.dart';
import 'month_grid.dart';
import 'week_activity.dart';

enum CalendarViewMode { month, week }

/// 共享日记（UI_SPEC.md §5）：[月][周] 切换 + 内容区；新建一直可访问。
/// V1.1 版式：纸面留白 + 细线，降低 Material 感；周视图作为「生活痕迹图」。
class DiaryCalendarPage extends StatefulWidget {
  const DiaryCalendarPage({
    super.key,
    required this.spaceId,
    required this.spaceName,
  });

  final String spaceId;
  final String spaceName;

  @override
  State<DiaryCalendarPage> createState() => _DiaryCalendarPageState();
}

class _DiaryCalendarPageState extends State<DiaryCalendarPage> {
  CalendarViewMode _mode = CalendarViewMode.month;
  DateTime _month = DateTime.now();
  DateTime _weekAnchor = DateTime.now();
  Set<String> _activeDates = {};
  WeekActivity? _weekActivity;
  bool _loading = true;
  String? _error;
  StreamSubscription<DiaryChange>? _realtimeSub;
  int _fetchGeneration = 0;

  static const List<String> _weekdayLabels = [
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  DiaryRepository get _repo => DiaryRepository(Supabase.instance.client);

  DateTime get _monthFirst => DateTime(_month.year, _month.month, 1);
  DateTime get _monthLast => DateTime(_month.year, _month.month + 1, 0);
  DateTime get _weekStart => mondayOf(_weekAnchor);

  @override
  void initState() {
    super.initState();
    _initRealtimeThenLoad();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _initRealtimeThenLoad() async {
    final subscription = _repo.watchDiaryChanges(widget.spaceId);
    _realtimeSub = subscription.stream.listen((_) => _load());
    try {
      await subscription.ready.timeout(const Duration(seconds: 15));
    } catch (_) {}
    if (!mounted) return;
    await _load();
  }

  Future<void> _load() async {
    final generation = ++_fetchGeneration;
    try {
      final weekEnd = _weekStart.add(const Duration(days: 6));
      final results = await Future.wait([
        _repo.getByDateRange(widget.spaceId, _monthFirst, _monthLast),
        _repo.getByDateRange(widget.spaceId, _weekStart, weekEnd),
      ]);
      if (!mounted || generation != _fetchGeneration) return;
      final monthRows = results[0];
      final weekRows = results[1];
      setState(() {
        _activeDates = monthRows.map((r) => r['diary_date'] as String).toSet();
        _weekActivity = calculateWeeklyActivity(
          weekRows,
          weekStart: _weekStart,
        );
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted || generation != _fetchGeneration) return;
      setState(() {
        _loading = false;
        _error = '发生了一点问题，请检查网络后重试';
      });
    }
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
    _load();
  }

  void _shiftWeek(int delta) {
    setState(() => _weekAnchor = _weekAnchor.add(Duration(days: 7 * delta)));
    _load();
  }

  Future<void> _openEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiaryEditorPage(spaceId: widget.spaceId),
      ),
    );
    await _load();
  }

  void _openDay(DateTime date) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DayDiariesPage(
          spaceId: widget.spaceId,
          spaceName: widget.spaceName,
          date: date,
        ),
      ),
    );
  }

  void _openHour(DateTime day, int hour) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HourDiariesPage(
          spaceId: widget.spaceId,
          spaceName: widget.spaceName,
          date: day,
          hour: hour,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: Theme.of(context).textTheme.bodySmall),
                  TextButton(onPressed: _load, child: const Text('重试')),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
              children: [
                Center(child: _buildModeSwitch()),
                const SizedBox(height: 20),
                if (_mode == CalendarViewMode.month)
                  _buildMonthView()
                else
                  _buildWeekView(),
              ],
            ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _openEditor,
        tooltip: '新建日记',
        child: const Icon(Icons.edit_outlined, size: 18),
      ),
    );
  }

  // ---------------- 月 / 周 切换 ----------------

  Widget _buildModeSwitch() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeChip('月', CalendarViewMode.month),
          _modeChip('周', CalendarViewMode.week),
        ],
      ),
    );
  }

  Widget _modeChip(String label, CalendarViewMode mode) {
    final selected = _mode == mode;
    return Semantics(
      button: true,
      selected: selected,
      label: label == '月' ? '月视图' : '周视图',
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              letterSpacing: 2,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _periodHeader(String label, VoidCallback onPrev, VoidCallback onNext) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          tooltip: '上一段',
          iconSize: 20,
          color: AppColors.textTertiary,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(child: Text(label, style: serifStyle(size: 17))),
        ),
        IconButton(
          onPressed: onNext,
          tooltip: '下一段',
          iconSize: 20,
          color: AppColors.textTertiary,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  // ---------------- 月视图 ----------------

  Widget _buildMonthView() {
    final cells = monthGridDates(_month.year, _month.month);
    return Column(
      children: [
        _periodHeader(
          '${_month.year}年${_month.month}月',
          () => _shiftMonth(-1),
          () => _shiftMonth(1),
        ),
        const SizedBox(height: 4),
        Row(
          children: _weekdayLabels
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 1,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.94,
          children: cells.map((date) {
            final inMonth = date.month == _month.month;
            final hasDiary = _activeDates.contains(_dateKey(date));
            final today = _isToday(date);
            return InkWell(
              onTap: inMonth ? () => _openDay(date) : null,
              customBorder: const CircleBorder(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: today
                        ? const BoxDecoration(
                            color: AppColors.primarySoft,
                            shape: BoxShape.circle,
                          )
                        : null,
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: today ? FontWeight.w600 : FontWeight.w400,
                        color: inMonth
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 4.5,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: hasDiary && inMonth
                          ? AppColors.sand
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        if (_activeDates.isEmpty)
          const EmptyHint(
            text: '今天还没有留下记录。',
            padding: EdgeInsets.only(top: 28),
          ),
      ],
    );
  }

  // ---------------- 周视图（生活痕迹图） ----------------

  Widget _buildWeekView() {
    final activity = _weekActivity;
    if (activity == null) return const SizedBox.shrink();
    final start = activity.days.first;
    final end = activity.days.last;
    String md(DateTime d) => '${d.month}/${d.day}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _periodHeader(
          '${md(start)} – ${md(end)}',
          () => _shiftWeek(-1),
          () => _shiftWeek(1),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const SizedBox(width: 56),
            ...activity.days.map((day) {
              final today = _isToday(day);
              return Expanded(
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        '周${_weekdayLabels[day.weekday - 1]}',
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.8,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: today
                            ? const BoxDecoration(
                                color: AppColors.primarySoft,
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: today
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: today
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 14),
        for (
          var hourIndex = 0;
          hourIndex < WeekActivity.bucketCount;
          hourIndex++
        )
          _buildHourRow(activity, hourIndex),
        const SizedBox(height: 18),
        Row(
          children: [
            const Text(
              '痕迹',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2.4,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 12),
            _traceDot(1),
            const SizedBox(width: 8),
            _traceDot(2),
            const SizedBox(width: 8),
            _traceDot(3),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '颜色越深 = 该时间段留下记录的成员越多',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _traceDot(int members) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: weekActivityColor(members),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildHourRow(WeekActivity activity, int hourIndex) {
    final hour = WeekActivity.firstHour + hourIndex;
    return SizedBox(
      height: 26,
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                weekHourIntervalLabel(hour),
                style: const TextStyle(
                  fontSize: 8.5,
                  letterSpacing: 0.2,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
          ...List.generate(7, (dayIndex) {
            final count = activity.counts[dayIndex][hourIndex];
            final day = activity.days[dayIndex];
            return Expanded(
              child: Center(
                child: InkWell(
                  onTap: count > 0 ? () => _openHour(day, hour) : null,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(
                      child: Container(
                        width: count > 0 ? 15 : 5,
                        height: count > 0 ? 15 : 5,
                        decoration: BoxDecoration(
                          color: count > 0
                              ? weekActivityColor(count)
                              : AppColors.divider,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
