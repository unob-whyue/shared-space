import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Auth 的最薄封装（API_SERVICE.md §3）。
/// 不增加 AuthManager / AuthCoordinator / AuthUseCase。
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  User? currentUser() => _client.auth.currentUser;
}
