import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_tokens.dart';
import '../diary/diary_detail_page.dart';
import '../diary/diary_enums.dart';
import '../diary/diary_repository.dart';
import '../profile/color_keys.dart';

/// 日记列表条目（当日集合 / 时间段集合 / 我的记录共用）。
class DiaryListItem extends StatelessWidget {
  const DiaryListItem({super.key, required this.entry, required this.onTap});

  final Map<String, dynamic> entry;
  final VoidCallback onTap;

  static String formatHHmm(String? iso) {
    if (iso == null) return '';
    final t = DateTime.parse(iso).toLocal();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final profile = entry['profiles'] as Map<String, dynamic>? ?? const {};
    final rawColor = profile['color'];
    final authorColor =
        colorForKey(rawColor is String ? rawColor : 'blue');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(radius: 5, backgroundColor: authorColor),
        title: Text(
          entry['content'] as String? ?? '',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${formatHHmm(entry['created_at'] as String?)} · '
          '${profile['nickname'] ?? '未知'} · '
          '${WeatherKeyX.fromStorage(entry['weather'] as String? ?? 'unknown').label} · '
          '${MoodKeyX.fromStorage(entry['mood'] as String? ?? 'calm').label}',
        ),
        onTap: onTap,
      ),
    );
  }
}

/// 当日日记集合（UI_SPEC.md §7）：该日所有成员日记，created_at ASC。
class DayDiariesPage extends StatefulWidget {
  const DayDiariesPage({
    super.key,
    required this.spaceId,
    required this.spaceName,
    required this.date,
  });

  final String spaceId;
  final String spaceName;
  final DateTime date;

  @override
  State<DayDiariesPage> createState() => _DayDiariesPageState();
}

class _DayDiariesPageState extends State<DayDiariesPage> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  String? _error;
  StreamSubscription<DiaryChange>? _realtimeSub;
  int _fetchGeneration = 0;

  DiaryRepository get _repo => DiaryRepository(Supabase.instance.client);

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
      final rows =
          await _repo.getByDate(widget.spaceId, widget.date);
      if (!mounted || generation != _fetchGeneration) return;
      setState(() {
        _entries = rows;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.date.month}月${widget.date.day}日'),
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
                      child: Text('这一天还没有留下记录。',
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
