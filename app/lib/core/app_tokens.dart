import 'package:flutter/material.dart';

/// V1 设计基线：浅色、低饱和、柔和莫兰迪色系（Milestone 3）。
/// 全 App 唯一颜色来源：禁止在 Widget 中硬编码 Color(0xFF...)。
/// 只做颜色系统，不建 Typography/Spacing/ThemeService 等架构。
abstract final class AppColors {
  // 基础
  static const Color background = Color(0xFFFAF9F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF4F5154);
  static const Color textSecondary = Color(0xFF85878A);
  static const Color border = Color(0xFFE7E4DF);
  static const Color divider = Color(0xFFEEECE8);

  // 主色：偏灰的蓝紫
  static const Color primary = Color(0xFF8D9AAF);
  static const Color primarySoft = Color(0xFFE8EBF0);

  // 语义色（低饱和，只做提示，不做大面积背景）
  static const Color error = Color(0xFFB98B8B);
  static const Color success = Color(0xFF8EA994);
  static const Color warning = Color(0xFFB5A078);

  // 图片等之上的暗色遮罩
  static const Color scrim = Color(0x99000000);
}

/// 周视图活动密度色阶（同一色系深浅，基于 primary；UI_SPEC.md §8）：
/// 0 人 → 空；1 人 → 很浅；2 人 → 中等；3 人及以上 → 更明显。
Color weekActivityColor(int distinctMembers) {
  if (distinctMembers <= 0) return Colors.transparent;
  if (distinctMembers == 1) return const Color(0xFFE3E8EE);
  if (distinctMembers == 2) return const Color(0xFFC3CEDC);
  return const Color(0xFF9FB0C4);
}

/// V1 统一浅色主题（唯一主题入口；不做 Dark Mode / 换肤）。
ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.primary)
      .copyWith(
    primary: AppColors.primary,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.border,
    outlineVariant: AppColors.divider,
    error: AppColors.error,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.divider),
  );
}
