import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_kit.dart';
import '../../core/app_tokens.dart';
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
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
                  children: [
                    Text(widget.spaceName, style: serifStyle(size: 21)),
                    const SizedBox(height: 22),
                    // 邀请码：其他成员靠它加入（PRD §7 用户友好凭证）
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: AppColors.border, width: 0.6),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '邀请码',
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 2.4,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.spaceInviteCode ?? '',
                                  style: serifStyle(
                                      size: 20, letterSpacing: 4),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '复制邀请码',
                            icon: const Icon(Icons.copy_outlined, size: 20),
                            color: AppColors.textTertiary,
                            onPressed: _copyInviteCode,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    SectionLabel(text: '成员 · ${_members.length}/10'),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _members
                          .map((m) => Chip(
                                avatar: AuthorDot(
                                  colorKey: m['color'] as String?,
                                  size: 10,
                                ),
                                label: Text(m['nickname'] as String),
                              ))
                          .toList(),
                    ),
                    if (_members.isEmpty)
                      const EmptyHint(
                        text: '创建一个共享空间，和朋友开始记录吧。',
                        padding: EdgeInsets.only(top: 28),
                      ),
                  ],
                ),
    );
  }
}
