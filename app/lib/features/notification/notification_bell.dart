import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_repository.dart';
import 'notifications_page.dart';

/// 右上角通知铃铛：未读 Badge + 打开通知中心。
/// 自管理订阅与未读数，页面返回后刷新。
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;
  StreamSubscription<NotificationChange>? _sub;

  NotificationRepository get _repo =>
      NotificationRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final subscription = _repo.watchMyNotifications();
    _sub = subscription.stream.listen((_) => _refresh());
    try {
      await subscription.ready.timeout(const Duration(seconds: 15));
    } catch (_) {}
    if (mounted) await _refresh();
  }

  Future<void> _refresh() async {
    try {
      final count = await _repo.unreadCount();
      if (mounted) setState(() => _unread = count);
    } catch (_) {}
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '通知',
      onPressed: _open,
      icon: Badge.count(
        count: _unread,
        isLabelVisible: _unread > 0,
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
