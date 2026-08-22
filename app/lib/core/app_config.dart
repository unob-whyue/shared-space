/// 应用配置。通过 --dart-define 注入（Android / iOS / Web 通用）。
/// 注意：不使用 dart:io / Platform，保证 Flutter Web 可编译。
/// 用法：flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class AppConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String serviceRoleKey =
      String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
