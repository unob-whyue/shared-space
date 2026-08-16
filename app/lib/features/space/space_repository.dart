import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';

/// spaces / space_memberships 数据访问（API_SERVICE.md §5）。
class SpaceRepository {
  SpaceRepository(this._client);

  final SupabaseClient _client;

  /// 当前用户的全部空间（底层支持多空间）。
  Future<List<Map<String, dynamic>>> getMySpaces() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AppError('未登录');
    final rows = await _client
        .from('space_memberships')
        .select('spaces(*)')
        .eq('user_id', uid);
    return rows
        .map((r) => (r['spaces'] as Map<String, dynamic>))
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<Map<String, dynamic>> getSpace(String spaceId) async {
    return await _client.from('spaces').select().eq('id', spaceId).single();
  }

  Future<List<Map<String, dynamic>>> getMembers(String spaceId) async {
    final rows = await _client
        .from('space_memberships')
        .select('profiles(id, nickname, color)')
        .eq('space_id', spaceId)
        .order('joined_at');
    return rows.map((r) => r['profiles'] as Map<String, dynamic>).toList();
  }

  /// 创建空间：RPC 单事务完成「建空间 + 生成邀请码 + 创建者成为第一名成员」。
  Future<Map<String, dynamic>> createSpace(String name) async {
    final row = await _client
        .rpc('create_space', params: {'p_name': name})
        .single();
    return row;
  }

  /// 底层 RPC 调用；业务语义映射在 SpaceService.joinByInviteCode。
  Future<Map<String, dynamic>> joinByInviteCodeRpc(String inviteCode) async {
    final row = await _client
        .rpc('join_space_by_invite_code', params: {'p_invite_code': inviteCode})
        .single();
    return row;
  }
}
