import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_kit.dart';
import '../../core/app_tokens.dart';
import '../calendar/day_diaries_page.dart';
import '../diary/diary_detail_page.dart';
import 'diary_repository.dart';

/// 我的记录（UI_SPEC.md §16）：只显示当前用户自己的日记。
/// V1.1 版式：按日期分组（日期 > 时间 > 正文 > 天气 / 心情），
/// 弱化卡片边框与阴影，像一本连续展开的个人手记。
class MyRecordsPage extends StatefulWidget {
  const MyRecordsPage({super.key});

  @override
  State<MyRecordsPage> createState() => _MyRecordsPageState();
}

class _MyRecordsPageState extends State<MyRecordsPage> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  String? _error;

  static const List<String> _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  DiaryRepository get _repo => DiaryRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _repo.getMyDiaries();
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

  String _dateLabel(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.year}年${d.month}月${d.day}日 · 周${_weekdayLabels[d.weekday - 1]}';
  }

  List<Widget> _buildGroups(BuildContext context) {
    final widgets = <Widget>[];
    String? currentDate;
    for (final entry in _entries) {
      final date = entry['diary_date'] as String? ?? '';
      if (date != currentDate) {
        currentDate = date;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(
              top: widgets.isEmpty ? 10 : 34,
              bottom: 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_dateLabel(date), style: serifStyle(size: 18.5)),
                const SizedBox(height: 10),
                Container(height: 0.7, color: AppColors.divider),
              ],
            ),
          ),
        );
      }
      widgets.add(
        DiaryListItem(
          entry: entry,
          showAuthor: false,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DiaryDetailPage(
                  diaryId: entry['id'] as String,
                  spaceId: entry['space_id'] as String,
                ),
              ),
            );
            await _load();
          },
        ),
      );
    }
    return widgets;
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
                      Text(_error!,
                          style: Theme.of(context).textTheme.bodySmall),
                      TextButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : _entries.isEmpty
                  ? const EmptyHint(text: '还没有写下第一篇日记。')
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 48),
                      children: _buildGroups(context),
                    ),
    );
  }
}
