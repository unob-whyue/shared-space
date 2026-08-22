import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_tokens.dart';
import '../diary/diary_detail_page.dart';
import '../diary/diary_repository.dart';
import 'day_diaries_page.dart';
import 'week_activity.dart';

/// 周视图时间桶日记集合（UI_SPEC.md §9）：
/// 该日期该时间区间（HH:00–HH+1:00）所有成员创建的日记，不按成员拆分。
class HourDiariesPage extends StatefulWidget {
  const HourDiariesPage({
    super.key,
    required this.spaceId,
    required this.spaceName,
    required this.date,
    required this.hour,
  });

  final String spaceId;
  final String spaceName;
  final DateTime date;
  final int hour;

  @override
  State<HourDiariesPage> createState() => _HourDiariesPageState();
}

class _HourDiariesPageState extends State<HourDiariesPage> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  String? _error;

  DiaryRepository get _repo => DiaryRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // 与周视图网格同口径：按 created_at 落入该时间区间。
      // 不用 diary_date 过滤，避免周视图（created_at）与详情页（diary_date）
      // 口径不一致导致部分日记“消失”。
      final from = DateTime(
          widget.date.year, widget.date.month, widget.date.day, widget.hour);
      final to = from
          .add(const Duration(hours: 1))
          .subtract(const Duration(milliseconds: 1));
      final rows = await _repo.getByCreatedAtRange(widget.spaceId, from, to);
      if (!mounted) return;
      setState(() {
        _entries = rows;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '发生了一点问题，请检查网络后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final interval = weekHourIntervalLabel(widget.hour);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.date.month}月${widget.date.day}日 $interval'),
      ),
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
              : _entries.isEmpty
                  ? const Center(
                      child: Text('这个时间段还没有留下记录。',
                          style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return DiaryListItem(
                          entry: entry,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DiaryDetailPage(
                                diaryId: entry['id'] as String,
                                spaceId: widget.spaceId,
                                spaceName: widget.spaceName,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
