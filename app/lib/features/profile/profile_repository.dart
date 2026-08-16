import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';

/// profiles 数据访问（API_SERVICE.md §4）。
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> getMyProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AppError('未登录');
    return await _client.from('profiles').select().eq('id', uid).single();
  }

  Future<Map<String, dynamic>> updateMyProfile({
    required String nickname,
    required String color,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AppError('未登录');
    return await _client
        .from('profiles')
        .update({'nickname': nickname, 'color': color})
        .eq('id', uid)
        .select()
        .single();
  }
}
