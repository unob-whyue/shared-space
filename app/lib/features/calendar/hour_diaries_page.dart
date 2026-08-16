import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_tokens.dart';
import '../diary/diary_detail_page.dart';
import '../diary/diary_repository.dart';
import 'day_diaries_page.dart';

/// 周视图时间桶日记集合（UI_SPEC.md §9）：
/// 该日期该小时（HH:00–HH:59）所有成员创建的日记，不按成员拆分。
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
      final rows = await _repo.getByDate(widget.spaceId, widget.date);
      final filtered = rows.where((row) {
        final createdAt = row['created_at'] as String?;
        if (createdAt == null) return false;
        return DateTime.parse(createdAt).toLocal().hour == widget.hour;
      }).toList();
      if (!mounted) return;
      setState(() {
        _entries = filtered;
        _loading = false;
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
    final hh = widget.hour.toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.date.month}月${widget.date.day}日 $hh:00–$hh:59'),
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
