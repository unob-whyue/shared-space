import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_kit.dart';
import '../../core/app_tokens.dart';
import '../diary/diary_detail_page.dart';
import 'notification_repository.dart';

/// App 内部通知中心（V1.1）：批注通知，按时间倒序，已读/未读有区分。
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String? _error;

  NotificationRepository get _repo =>
      NotificationRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _repo.getMyNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = rows;
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

  Future<void> _markAllRead() async {
    try {
      await _repo.markAllRead();
      await _load();
    } catch (_) {
      _toast('操作失败，请重试');
    }
  }

  Future<void> _open(Map<String, dynamic> notification) async {
    final id = notification['id'] as String;
    if (notification['read_at'] == null) {
      try {
        await _repo.markRead(id);
      } catch (_) {}
    }

    final diaryId = notification['diary_id'] as String?;
    if (diaryId == null) {
      _toast('日记已删除或不可用');
      await _load();
      return;
    }

    final diary = notification['diary'];
    final spaceId = diary is Map<String, dynamic>
        ? diary['space_id'] as String?
        : null;
    final annotationId = notification['annotation_id'] as String?;

    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DiaryDetailPage(
        diaryId: diaryId,
        spaceId: spaceId ?? '',
        spaceName: '',
        initialAnnotationId: annotationId,
      ),
    ));
    await _load();
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final t = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final sameDay = t.year == now.year &&
        t.month == now.month &&
        t.day == now.day;
    if (sameDay) return '今天 $hh:$mm';
    if (t.year == now.year) return '${t.month}月${t.day}日 $hh:$mm';
    return '${t.year}年${t.month}月${t.day}日 $hh:$mm';
  }

  String _diaryTitle(Map<String, dynamic> notification) {
    final diary = notification['diary'];
    final rawDate = diary is Map<String, dynamic>
        ? diary['diary_date'] as String?
        : null;
    if (rawDate == null || rawDate.isEmpty) return '一篇日记';
    final parts = rawDate.split('-');
    if (parts.length != 3) return '$rawDate的日记';
    final month = int.tryParse(parts[1]) ?? parts[1];
    final day = int.tryParse(parts[2]) ?? parts[2];
    return '$month月$day日的日记';
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          if (_notifications.any((n) => n['read_at'] == null))
            TextButton(
              onPressed: _markAllRead,
              child: const Text('全部已读'),
            ),
        ],
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
              : _notifications.isEmpty
                  ? const EmptyHint(text: '还没有通知。')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, _) => const HairLine(),
                      itemBuilder: (context, index) {
                        final n = _notifications[index];
                        return _buildTile(n);
                      },
                    ),
    );
  }

  Widget _buildTile(Map<String, dynamic> n) {
    final actor = n['actor'];
    final nickname = actor is Map<String, dynamic>
        ? actor['nickname'] as String? ?? '未知'
        : '未知';
    final rawColor = actor is Map<String, dynamic> ? actor['color'] : null;
    final read = n['read_at'] != null;

    final annotation = n['annotation'];
    final selectedText = annotation is Map<String, dynamic>
        ? annotation['selected_text'] as String?
        : null;

    final title = '$nickname 批注了你的《${_diaryTitle(n)}》';
    final subtitleParts = [
      _formatTime(n['created_at'] as String?),
      if (selectedText != null && selectedText.isNotEmpty) '「$selectedText」',
    ];

    return InkWell(
      onTap: () => _open(n),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: AuthorDot(
                colorKey: rawColor is String ? rawColor : 'blue',
                size: 7,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.6,
                      fontWeight:
                          read ? FontWeight.w400 : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitleParts.join(' · '),
                    style: const TextStyle(
                      fontSize: 11.5,
                      letterSpacing: 0.6,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (!read)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 10),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
