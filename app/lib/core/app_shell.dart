import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/calendar/diary_calendar_page.dart';
import '../features/diary/my_records_page.dart';
import '../features/profile/profile_page.dart';
import '../features/space/space_detail_page.dart';
import '../features/space/space_repository.dart';
import '../features/space/spaces_page.dart';
import 'app_tokens.dart';

/// App 外壳：抽屉式侧边栏 + 当前空间（UI_SPEC.md §2）。
/// V1 只显示：共享日记 / 我的记录 / 空间设置；当前空间显示在抽屉头部。
/// 不显示书影音 / 全国地图 / 通知等未来入口，不建空间管理器。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  Map<String, dynamic>? _currentSpace;
  int _pageIndex = 0;
  bool _loading = true;

  static const List<String> _titles = ['共享日记', '我的记录', '空间设置'];

  SpaceRepository get _spaceRepo => SpaceRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await ensureProfileSetup(context);
    await _loadSpaces();
  }

  Future<void> _loadSpaces() async {
    try {
      final spaces = await _spaceRepo.getMySpaces();
      if (!mounted) return;
      setState(() {
        if (spaces.isNotEmpty &&
            (_currentSpace == null ||
                !spaces.any((s) => s['id'] == _currentSpace!['id']))) {
          _currentSpace = spaces.first;
        }
        if (spaces.isEmpty) _currentSpace = null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openMySpaces() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SpacesPage()),
    );
    await _loadSpaces();
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
  }

  void _go(int index) {
    Navigator.of(context).pop();
    setState(() => _pageIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final space = _currentSpace;
    if (space == null) {
      // 无空间：整页走创建/加入流程（无抽屉）
      return const SpacesPage();
    }
    final spaceId = space['id'] as String;
    final spaceName = space['name'] as String;
    final inviteCode = space['invite_code'] as String?;

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_pageIndex])),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primarySoft),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    spaceName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '当前空间',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.auto_stories_outlined),
              title: const Text('共享日记'),
              selected: _pageIndex == 0,
              onTap: () => _go(0),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('我的记录'),
              selected: _pageIndex == 1,
              onTap: () => _go(1),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('空间设置'),
              selected: _pageIndex == 2,
              onTap: () => _go(2),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.swap_horiz_outlined),
              title: const Text('所有空间'),
              onTap: () {
                Navigator.of(context).pop();
                _openMySpaces();
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('我的资料'),
              onTap: () {
                Navigator.of(context).pop();
                _openProfile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('登出'),
              onTap: () {
                Navigator.of(context).pop();
                Supabase.instance.client.auth.signOut();
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _pageIndex,
        children: [
          DiaryCalendarPage(
            key: ValueKey('cal-$spaceId'),
            spaceId: spaceId,
            spaceName: spaceName,
          ),
          MyRecordsPage(
            key: ValueKey('my-$spaceId'),
          ),
          SpaceDetailPage(
            key: ValueKey('set-$spaceId'),
            spaceId: spaceId,
            spaceName: spaceName,
            spaceInviteCode: inviteCode,
          ),
        ],
      ),
    );
  }
}
