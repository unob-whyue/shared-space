import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../core/app_kit.dart';
import '../profile/profile_page.dart';
import '../profile/profile_rules.dart';
import 'space_detail_page.dart';
import 'space_repository.dart';
import 'space_service.dart';

/// 我的空间列表（V1：列表 + 创建 + 邀请码加入 + 资料入口 + 登出）。
class SpacesPage extends StatefulWidget {
  const SpacesPage({super.key});

  @override
  State<SpacesPage> createState() => _SpacesPageState();
}

class _SpacesPageState extends State<SpacesPage> {
  List<Map<String, dynamic>> _spaces = [];
  bool _loading = true;
  String? _error;

  SpaceRepository get _repo => SpaceRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _load();
    if (!mounted) return;
    await ensureProfileSetup(context);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final spaces = await _repo.getMySpaces();
      if (mounted) setState(() => _spaces = spaces);
    } catch (_) {
      if (mounted) setState(() => _error = '发生了一点问题，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createSpace() async {
    final name = await _promptText(
      title: '创建共享空间',
      label: '空间名称',
      validator: validateSpaceName,
    );
    if (name == null) return;
    try {
      await _repo.createSpace(name);
      await _load();
    } catch (_) {
      _toast('创建失败，请重试');
    }
  }

  Future<void> _joinSpace() async {
    final code = await _promptText(
      title: '加入共享空间',
      label: '邀请码',
      textFormatter: normalizeInviteCode,
      validator: (value) =>
          isValidInviteCodeFormat(value) ? null : '邀请码格式不正确（8 位大写字母数字）',
    );
    if (code == null) return;
    try {
      await SpaceService(_repo).joinByInviteCode(code);
      await _load();
    } catch (e) {
      _toast(e is SpaceJoinError ? e.userMessage : '加入失败，请重试');
    }
  }

  Future<String?> _promptText({
    required String title,
    required String label,
    String? Function(String)? validator,
    String Function(String)? textFormatter,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: textFormatter == null
                    ? null
                    : [TextInputFormatter.withFunction(
                        (oldValue, newValue) => TextEditingValue(
                          text: textFormatter(newValue.text),
                          selection: TextSelection.collapsed(
                              offset: textFormatter(newValue.text).length),
                        ),
                      )],
                decoration: InputDecoration(
                  labelText: label,
                  errorText: error,
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消')),
                FilledButton(
                  onPressed: () {
                    final value = textFormatter != null
                        ? textFormatter(controller.text)
                        : controller.text.trim();
                    final message = validator?.call(value);
                    if (message != null) {
                      setDialogState(() => error = message);
                      return;
                    }
                    Navigator.pop(context, value);
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('共享空间'),
        actions: [
          IconButton(
              onPressed: _createSpace,
              tooltip: '创建空间',
              icon: const Icon(Icons.add)),
          IconButton(
              onPressed: _joinSpace,
              tooltip: '加入空间',
              icon: const Icon(Icons.group_add_outlined)),
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ProfilePage(),
            )),
            tooltip: '我的资料',
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
              onPressed: _signOut,
              tooltip: '登出',
              icon: const Icon(Icons.logout)),
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
              : _spaces.isEmpty
                  ? const EmptyHint(
                      text: '创建一个共享空间，和朋友开始记录吧。')
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _spaces.length,
                      separatorBuilder: (_, _) => const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: HairLine(),
                      ),
                      itemBuilder: (context, index) {
                        final space = _spaces[index];
                        return ListTile(
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(space['name'] as String),
                          subtitle: Text('邀请码：${space['invite_code']}'),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SpaceDetailPage(
                                spaceId: space['id'] as String,
                                spaceName: space['name'] as String,
                                spaceInviteCode:
                                    space['invite_code'] as String?,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
