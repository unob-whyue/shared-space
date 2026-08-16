import 'dart:io';

/// 应用配置。通过 --dart-define 注入，测试环境可用环境变量兜底。
/// 用法：flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class AppConfig {
  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _serviceRoleKey =
      String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');

  static String get url =>
      _url.isNotEmpty ? _url : (Platform.environment['SUPABASE_URL'] ?? '');

  static String get anonKey => _anonKey.isNotEmpty
      ? _anonKey
      : (Platform.environment['SUPABASE_ANON_KEY'] ?? '');

  static String get serviceRoleKey => _serviceRoleKey.isNotEmpty
      ? _serviceRoleKey
      : (Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ?? '');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
