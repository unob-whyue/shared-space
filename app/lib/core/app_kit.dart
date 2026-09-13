import 'package:flutter/material.dart';

import '../features/profile/color_keys.dart';
import 'app_tokens.dart';

/// 少量共享 UI 原语：只在「确实重复出现」的模式上提取，不引入设计系统框架。
/// 全部颜色来自 app_tokens.dart。

/// 作者色点：使用 profile 的 color_key，不使用头像。
class AuthorDot extends StatelessWidget {
  const AuthorDot({super.key, required this.colorKey, this.size = 6});

  final String? colorKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorForKey(colorKey ?? 'blue'),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 小标题 + 细线（editorial 分区标签）。
class SectionLabel extends StatelessWidget {
  const SectionLabel({
    super.key,
    required this.text,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider()),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

/// 空状态提示（多处复用，取代各页重复的居中灰字）。
class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.text, this.padding});

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          padding ?? const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.8,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// 极细分割线（比 Divider 更安静）。
class HairLine extends StatelessWidget {
  const HairLine({super.key, this.indent = 0, this.endIndent = 0});

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent, right: endIndent),
      child: Container(height: 0.7, color: AppColors.divider),
    );
  }
}

/// 静态装饰：柔和色块（少量使用，只做版式呼吸，不抢内容层级）。
class SoftBlob extends StatelessWidget {
  const SoftBlob({
    super.key,
    required this.size,
    this.color = AppColors.primarySoft,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
