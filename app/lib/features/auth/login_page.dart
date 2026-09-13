import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_shell.dart';
import '../../core/app_tokens.dart';
import 'auth_repository.dart';

/// 静态装饰圆点（少量使用，只做版式呼吸）。
class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// 登录 / 注册页（UI_SPEC.md §4）：留白、克制的编辑物气质。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  AuthRepository get _repo => AuthRepository(Supabase.instance.client);

  /// 客户端表单校验（PRD §47）。返回错误文案，null 表示通过。
  /// 注意：空邮箱会触发服务端「匿名注册被禁」的误导性报错，必须先拦。
  String? _validate({required bool isSignUp}) {
    final email = _email.text.trim();
    if (email.isEmpty) return '请输入邮箱';
    if (!email.contains('@') || !email.contains('.')) return '邮箱格式不正确';
    if (_password.text.isEmpty) return '请输入密码';
    if (isSignUp && _password.text.length < 6) return '密码至少 6 位';
    return null;
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool isSignUp = false,
  }) async {
    final validationError = _validate(isSignUp: isSignUp);
    if (validationError != null) {
      setState(() {
        _error = validationError;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 把真实失败原因转成可读文案（PRD §46 错误处理）。
  String _friendlyError(Object e) {
    if (e is AuthRetryableFetchException) {
      return '网络不可用，请检查网络后重试';
    }
    if (e is AuthException) {
      final msg = e.message;
      if (msg.contains('rate limit') || msg.contains('Too many')) {
        return '操作过于频繁，请稍后再试（$msg）';
      }
      return msg;
    }
    if (e is PostgrestException) {
      return e.code == '429' ? '操作过于频繁，请稍后再试' : e.message;
    }
    return '发生了一点问题，请稍后再试';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _Dot(color: AppColors.dustyBlue),
                      SizedBox(width: 10),
                      _Dot(color: AppColors.sage),
                      SizedBox(width: 10),
                      _Dot(color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    '共享空间',
                    textAlign: TextAlign.center,
                    style: serifStyle(size: 26, letterSpacing: 8),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '记录我们共同的生活',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 3,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 46),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: '邮箱'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '密码'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12.5,
                        height: 1.6,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _loading
                        ? null
                        : () => _run(
                            () => _repo.signIn(
                              email: _email.text.trim(),
                              password: _password.text,
                            ),
                          ),
                    child: Text(_loading ? '处理中…' : '登录'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => _run(
                            () => _repo.signUp(
                              email: _email.text.trim(),
                              password: _password.text,
                            ),
                            isSignUp: true,
                          ),
                    child: Text(_loading ? '处理中…' : '注册新账号'),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '新用户：在上方填写邮箱和密码后点击「注册新账号」',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11.5,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
