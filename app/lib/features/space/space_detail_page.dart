import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_tokens.dart';
import '../profile/color_keys.dart';
import 'space_repository.dart';

/// 空间设置（V1：邀请码 + 成员列表）。
/// 日记浏览已迁移到共享日记（月/周/日）与我的记录页面。
class SpaceDetailPage extends StatefulWidget {
  const SpaceDetailPage({
    super.key,
    required this.spaceId,
    required this.spaceName,
    this.spaceInviteCode,
  });

  final String spaceId;
  final String spaceName;
  final String? spaceInviteCode;

  @override
  State<SpaceDetailPage> createState() => _SpaceDetailPageState();
}

class _SpaceDetailPageState extends State<SpaceDetailPage> {
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  String? _error;

  SpaceRepository get _spaceRepo => SpaceRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await _spaceRepo.getMembers(widget.spaceId);
      if (!mounted) return;
      setState(() {
        _members = members;
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

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyInviteCode() async {
    final code = widget.spaceInviteCode;
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    _toast('邀请码已复制');
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
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(widget.spaceName,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    // 邀请码：其他成员靠它加入（PRD §7 用户友好凭证）
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.key_outlined),
                        title: const Text('邀请码'),
                        subtitle: Text(
                          widget.spaceInviteCode ?? '',
                          style: const TextStyle(
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: '复制邀请码',
                          icon: const Icon(Icons.copy_outlined, size: 20),
                          onPressed: _copyInviteCode,
                        ),
                      ),
                    ),
                    const Divider(height: 32),
                    Text('成员（${_members.length}/10）',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _members
                          .map((m) => Chip(
                                avatar: CircleAvatar(
                                    backgroundColor:
                                        colorForKey(m['color'] as String? ?? 'blue'),
                                    radius: 8),
                                label: Text(m['nickname'] as String),
                              ))
                          .toList(),
                    ),
                    if (_members.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('创建一个共享空间，和朋友开始记录吧。',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),
                  ],
                ),
    );
  }
}
