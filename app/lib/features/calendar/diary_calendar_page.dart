import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_tokens.dart';
import '../diary/diary_editor_page.dart';
import '../diary/diary_repository.dart';
import 'day_diaries_page.dart';
import 'hour_diaries_page.dart';
import 'month_grid.dart';
import 'week_activity.dart';

enum CalendarViewMode { month, week }

/// 共享日记（UI_SPEC.md §5）：[月][周] 切换 + 内容区；新建一直可访问。
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

  static const List<String> _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

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
        _activeDates =
            monthRows.map((r) => r['diary_date'] as String).toSet();
        _weekActivity =
            calculateWeeklyActivity(weekRows, weekStart: _weekStart);
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

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
    _load();
  }

  void _shiftWeek(int delta) {
    setState(() =>
        _weekAnchor = _weekAnchor.add(Duration(days: 7 * delta)));
    _load();
  }

  Future<void> _openEditor() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DiaryEditorPage(spaceId: widget.spaceId),
    ));
    await _load();
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
                      Text(_error!),
                      TextButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: SegmentedButton<CalendarViewMode>(
                        segments: const [
                          ButtonSegment(
                              value: CalendarViewMode.month, label: Text('月')),
                          ButtonSegment(
                              value: CalendarViewMode.week, label: Text('周')),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (selection) =>
                            setState(() => _mode = selection.first),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_mode == CalendarViewMode.month)
                      _buildMonthView()
                    else
                      _buildWeekView(),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openEditor,
        child: const Icon(Icons.edit),
      ),
    );
  }

  // ---------------- 月视图 ----------------

  Widget _buildMonthView() {
    final cells = monthGridDates(_month.year, _month.month);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
                onPressed: () => _shiftMonth(-1),
                icon: const Icon(Icons.chevron_left)),
            Text('${_month.year}年${_month.month}月',
                style: Theme.of(context).textTheme.titleMedium),
            IconButton(
                onPressed: () => _shiftMonth(1),
                icon: const Icon(Icons.chevron_right)),
          ],
        ),
        Row(
          children: _weekdayLabels
              .map((label) => Expanded(
                    child: Center(
                      child: Text(label,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ),
                  ))
              .toList(),
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cells.map((date) {
            final inMonth = date.month == _month.month;
            final hasDiary = _activeDates.contains(_dateKey(date));
            return InkWell(
              onTap: inMonth
                  ? () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => DayDiariesPage(
                          spaceId: widget.spaceId,
                          spaceName: widget.spaceName,
                          date: date,
                        ),
                      ))
                  : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      color: inMonth
                          ? AppColors.textPrimary
                          : AppColors.divider,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 6,
                    width: 6,
                    child: hasDiary && inMonth
                        ? const DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        if (_activeDates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('今天还没有留下记录。',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
      ],
    );
  }

  // ---------------- 周视图 ----------------

  Widget _buildWeekView() {
    final activity = _weekActivity;
    if (activity == null) return const SizedBox.shrink();
    final start = activity.days.first;
    final end = activity.days.last;
    String md(DateTime d) => '${d.month}/${d.day}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
                onPressed: () => _shiftWeek(-1),
                icon: const Icon(Icons.chevron_left)),
            Text('${md(start)} – ${md(end)}',
                style: Theme.of(context).textTheme.titleMedium),
            IconButton(
                onPressed: () => _shiftWeek(1),
                icon: const Icon(Icons.chevron_right)),
          ],
        ),
        Row(
          children: [
            const SizedBox(width: 62),
            ...activity.days.map((day) => Expanded(
                  child: Center(
                    child: Text(
                      '周${_weekdayLabels[day.weekday - 1]} ${day.day}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ),
                )),
          ],
        ),
        for (var hourIndex = 0;
            hourIndex < WeekActivity.bucketCount;
            hourIndex++)
          Row(
            children: [
              SizedBox(
                width: 62,
                child: Text(
                  weekHourIntervalLabel(WeekActivity.firstHour + hourIndex),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 9),
                ),
              ),
              ...List.generate(7, (dayIndex) {
                final count = activity.counts[dayIndex][hourIndex];
                final day = activity.days[dayIndex];
                final hour = WeekActivity.firstHour + hourIndex;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(1),
                    child: InkWell(
                      onTap: count > 0
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => HourDiariesPage(
                                    spaceId: widget.spaceId,
                                    spaceName: widget.spaceName,
                                    date: day,
                                    hour: hour,
                                  ),
                                ),
                              )
                          : null,
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: weekActivityColor(count),
                          border: Border.all(
                            color: AppColors.divider,
                            width: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        const SizedBox(height: 8),
        const Text('颜色深浅 = 该时间段有几位成员留下记录',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}
