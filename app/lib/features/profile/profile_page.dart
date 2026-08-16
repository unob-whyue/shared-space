import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_tokens.dart';
import 'color_keys.dart';
import 'profile_repository.dart';
import 'profile_rules.dart';

/// 注册后首次进入：昵称仍为默认值时强制完善资料。
/// AppShell 与 SpacesPage 共用（同一进程只检查一次）。
bool _setupCheckedOnce = false;

Future<void> ensureProfileSetup(BuildContext context) async {
  if (_setupCheckedOnce) return;
  _setupCheckedOnce = true;
  try {
    final profile =
        await ProfileRepository(Supabase.instance.client).getMyProfile();
    final nickname = profile['nickname'] as String? ?? '';
    if (!context.mounted) return;
    if (nickname.trim().isEmpty || nickname == '新成员') {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const ProfilePage(setupMode: true),
      ));
    }
  } catch (_) {
    // 检查失败不阻塞（用户可稍后从导航进入）
  }
}

/// 我的资料：昵称 + 个人标注颜色（V1 用户系统，PRD §3）。
/// 设计遵循 UI_SPEC 关键词：白色、克制、留白。
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.setupMode = false});

  /// setupMode：注册后首次设置（昵称仍为默认值时强制进入）。
  final bool setupMode;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nickname = TextEditingController();
  String _colorKey = 'blue';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  ProfileRepository get _repo => ProfileRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await _repo.getMyProfile();
      if (!mounted) return;
      setState(() {
        _nickname.text = profile['nickname'] as String? ?? '';
        _colorKey = isValidColorKey(profile['color'] as String? ?? '')
            ? profile['color'] as String
            : 'blue';
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

  Future<void> _save() async {
    final error = validateNickname(_nickname.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.updateMyProfile(
        nickname: _nickname.text.trim(),
        color: _colorKey,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存失败：当前网络不可用，请检查网络后重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.setupMode ? '完善我的资料' : '我的资料'),
        automaticallyImplyLeading: !widget.setupMode,
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : '保存'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (widget.setupMode) ...[
                  const Text('先介绍一下自己吧'),
                  const SizedBox(height: 4),
                  Text('昵称和颜色会展示给同一空间的成员',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 24),
                ],
                TextField(
                  controller: _nickname,
                  maxLength: 20,
                  decoration: const InputDecoration(
                    labelText: '昵称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text('个人标注颜色', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: kProfileColorKeys.map((def) {
                    final selected = _colorKey == def.key;
                    return GestureDetector(
                      onTap: () => setState(() => _colorKey = def.key),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: def.color,
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(
                                  color: AppColors.textPrimary, width: 3)
                              : Border.all(color: AppColors.border),
                        ),
                        child: selected
                            ? const Icon(Icons.check,
                                color: AppColors.surface, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!,
                      style: const TextStyle(color: AppColors.error)),
                ],
              ],
            ),
    );
  }
}
