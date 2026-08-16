import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_shell.dart';
import '../../core/app_tokens.dart';
import 'auth_repository.dart';

/// 登录 / 注册页（Spike 最小实现；居中卡片、留白，UI_SPEC.md §4）。
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

  Future<void> _run(Future<void> Function() action,
      {bool isSignUp = false}) async {
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 把真实失败原因转成可读文案（PRD §46 错误处理）。
  /// 网络层与业务层分开，便于定位（真机诊断用）。
  String _friendlyError(Object e) {
    if (e is AuthRetryableFetchException) {
      return '网络不可用，请检查网络后重试';
    }
    if (e is AuthException) {
      final msg = e.message;
      if (msg.contains('rate limit') || msg.contains('Too many')) {
        return '操作过于频繁，请稍后再试（$msg）';
      }
      // 其余服务端错误原样展示（邮箱格式、密码强度、账号已存在等）
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('共享空间',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                          labelText: '邮箱', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: '密码', border: OutlineInputBorder()),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: AppColors.error)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loading
                          ? null
                          : () => _run(
                                () => _repo.signIn(
                                    email: _email.text.trim(),
                                    password: _password.text),
                              ),
                      child: Text(_loading ? '处理中…' : '登录'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => _run(
                                () => _repo.signUp(
                                    email: _email.text.trim(),
                                    password: _password.text),
                                isSignUp: true,
                              ),
                      child: Text(_loading ? '处理中…' : '注册新账号'),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '新用户：在上方填写邮箱和密码后点击「注册新账号」',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
