import 'dart:async';

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
  await Supabase.initialize(
    url: AppConfig.url,
    publishableKey: AppConfig.anonKey,
  );
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
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
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
/// 连不上后端时给出明确提示与重试，不显示空白页（UI_SPEC.md §19）。
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _sub;
  Timer? _timeout;
  AuthState? _last;
  bool _unreachable = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      _last = state;
      _timeout?.cancel();
      if (mounted && _unreachable) setState(() => _unreachable = false);
    }, onError: (_) {});
    _armTimeout();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _armTimeout() {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 8), () {
      if (mounted && !_retrying && _last == null) {
        setState(() => _unreachable = true);
      }
    });
  }

  /// 重试：主动刷新会话；成功后 auth 流会推送事件，自动进入 App。
  Future<void> _retry() async {
    setState(() {
      _retrying = true;
      _unreachable = false;
    });
    try {
      await Supabase.instance.client.auth.refreshSession();
    } catch (_) {
      if (mounted) setState(() => _unreachable = true);
    } finally {
      if (mounted) setState(() => _retrying = false);
      _armTimeout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // 错误事件（例如断网时刷新 token 失败）不清空已登录状态。
        final state = snapshot.data ?? _last;
        if (state != null) {
          return state.session == null ? const LoginPage() : const AppShell();
        }
        if (snapshot.hasError || _unreachable) {
          return _ServerUnreachableNotice(retrying: _retrying, onRetry: _retry);
        }
        return const _WaitingScaffold();
      },
    );
  }
}

/// 等待首个鉴权事件时的静默画面（正常情况一闪而过）。
class _WaitingScaffold extends StatelessWidget {
  const _WaitingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// 连不上后端：明确告知 + 重试，而不是白屏。
class _ServerUnreachableNotice extends StatelessWidget {
  const _ServerUnreachableNotice({
    required this.retrying,
    required this.onRetry,
  });

  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('无法连接服务器', style: serifStyle(size: 19)),
                const SizedBox(height: 14),
                const Text(
                  '请检查网络后重试。\n你的日记都还在，恢复连接后即可继续。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.9,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 28),
                if (retrying)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  FilledButton(onPressed: onRetry, child: const Text('重试')),
              ],
            ),
          ),
        ),
      ),
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
