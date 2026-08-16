import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_tokens.dart';
import '../calendar/day_diaries_page.dart';
import '../diary/diary_detail_page.dart';
import '../diary/diary_repository.dart';

/// 我的记录（UI_SPEC.md §16）：只显示当前用户自己的日记，按日期排序。
/// 与共享日记是同一 DiaryEntry 的不同视图，禁止第二份数据。
class MyRecordsPage extends StatefulWidget {
  const MyRecordsPage({super.key});

  @override
  State<MyRecordsPage> createState() => _MyRecordsPageState();
}

class _MyRecordsPageState extends State<MyRecordsPage> {
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
              : _entries.isEmpty
                  ? const Center(
                      child: Text('还没有写下第一篇日记。',
                          style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return DiaryListItem(
                          entry: entry,
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
                        );
                      },
                    ),
    );
  }
}
