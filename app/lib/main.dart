import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'core/app_kit.dart';
import 'core/app_shell.dart';
import 'core/app_tokens.dart';
import 'features/auth/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.isConfigured) {
    runApp(const _NotConfiguredApp());
    return;
  }
  await Supabase.initialize(url: AppConfig.url, publishableKey: AppConfig.anonKey);
  runApp(const SharedSpaceApp());
}

class SharedSpaceApp extends StatelessWidget {
  const SharedSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '共享空间',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SplashPage(),
    );
  }
}

/// 启动页（V1.1）：品牌启动界面，约 3 秒后进入登录态门。
/// 使用异步延时而非阻塞主线程；冷启动白屏由 Android 原生 LaunchTheme 兜底。
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    await Future<void>.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            Stack(
              alignment: Alignment.center,
              children: [
                const SoftBlob(size: 196, color: AppColors.primarySoft),
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: const Image(
                    image: AssetImage('assets/app_icon.png'),
                    width: 116,
                    height: 116,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 44),
            Text('共享空间', style: serifStyle(size: 23, letterSpacing: 10)),
            const SizedBox(height: 14),
            const Text(
              '记录我们共同的生活',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 3.2,
                color: AppColors.textTertiary,
              ),
            ),
            const Spacer(flex: 4),
          ],
        ),
      ),
    );
  }
}

/// 登录态门：未登录 → 登录页；已登录 → App 外壳。
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: SizedBox.shrink());
        }
        final session = snapshot.data!.session;
        return session == null ? const LoginPage() : const AppShell();
      },
    );
  }
}

class _NotConfiguredApp extends StatelessWidget {
  const _NotConfiguredApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '未配置连接信息。\n请使用 --dart-define=SUPABASE_URL=... '
              '--dart-define=SUPABASE_ANON_KEY=... 启动。',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
