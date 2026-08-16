import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Spike 测试环境与账号工具。
/// 客户端只使用 URL + anon/publishable key；service_role 仅在
/// 环境变量中可选提供（用于确定性建号与自动清理），绝不进入仓库。
class SpikeEnv {
  static const String _u = String.fromEnvironment('SUPABASE_URL');
  static const String _a = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _s = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');

  static String get url =>
      _u.isNotEmpty ? _u : (Platform.environment['SUPABASE_URL'] ?? '');

  static String get anonKey =>
      _a.isNotEmpty ? _a : (Platform.environment['SUPABASE_ANON_KEY'] ?? '');

  static String get serviceRoleKey => _s.isNotEmpty
      ? _s
      : (Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ?? '');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static bool get hasServiceRole => serviceRoleKey.isNotEmpty;
}

/// 一个测试账号 = 一个独立 Supabase 客户端会话（模拟一台设备）。
class TestAccount {
  TestAccount({
    required this.email,
    required this.password,
    required this.client,
    required this.userId,
  });

  final String email;
  final String password;
  final SupabaseClient client;
  final String userId;

  static final int _stamp = DateTime.now().millisecondsSinceEpoch;

  /// 测试专用匿名客户端：implicit flow。
  /// gotrue 2.x 默认 PKCE 需要持久化 storage；纯 Dart 测试环境没有，
  /// 而 implicit 流程对 anon key 完全够用（App 本体不受影响，
  /// Supabase.initialize 自带 storage）。
  static SupabaseClient anonClient() => SupabaseClient(
        SpikeEnv.url,
        SpikeEnv.anonKey,
        authOptions:
            const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      );

  /// 真实注册（走公开 signUp）。项目需关闭 Confirm email（autoconfirm）。
  /// 若提供 admin（service_role），未确认账号可兜底确认。
  static Future<TestAccount> register(String tag,
      {SupabaseClient? admin}) async {
    final email = 'spike-$tag-$_stamp@gmail.com';
    const password = 'Spike-123456';
    final client = anonClient();
    final res = await client.auth.signUp(email: email, password: password);
    final uid = res.user?.id ?? '';
    if (res.session == null) {
      if (admin == null) {
        fail('注册未返回会话：项目可能仍要求邮箱确认。'
            '请在 Dashboard 关闭 Confirm email，或提供 service_role 环境变量。');
      }
      await admin.auth.admin.updateUserById(uid,
          attributes: AdminUserAttributes(emailConfirm: true));
    }
    await client.auth.signInWithPassword(email: email, password: password);
    final signedIn = client.auth.currentUser?.id ?? uid;
    return TestAccount(
        email: email, password: password, client: client, userId: signedIn);
  }
}

/// 轮询等待条件成立（Realtime 事件到达需要时间）。
Future<void> waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
  Duration interval = const Duration(milliseconds: 200),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (condition()) return;
    await Future<void>.delayed(interval);
  }
  fail('waitFor 超时（$timeout）');
}

/// 同 waitFor，但超时返回 false 而不是让测试失败（用于探测+重试）。
Future<bool> waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
  Duration interval = const Duration(milliseconds: 200),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (condition()) return true;
    await Future<void>.delayed(interval);
  }
  return false;
}
