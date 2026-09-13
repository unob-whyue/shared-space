import 'package:flutter/material.dart';

/// V1.1 设计基线（唯一颜色 / 主题来源）。
/// 只做「颜色 + 主题 + 少量排版常量」，不建 ThemeService / ColorService。
/// 关键词：米白暖纸 · 低饱和莫兰迪 · 细线 · 留白 · editorial。
abstract final class AppColors {
  // 纸张
  static const Color background = Color(0xFFF6F3EA);
  static const Color surface = Color(0xFFFEFDF8);
  static const Color surfaceMuted = Color(0xFFEFEAE0);
  static const Color sand = Color(0xFFD9CDBB);

  // 文字：深暖灰，不使用纯黑
  static const Color textPrimary = Color(0xFF4A4744);
  static const Color textSecondary = Color(0xFF8C847C);
  static const Color textTertiary = Color(0xFFB0A89E);

  // 细线
  static const Color border = Color(0xFFE3DCD0);
  static const Color divider = Color(0xFFEDE7DC);

  // 主色：低饱和陶土（新建 / 选中 / 未读点）
  static const Color primary = Color(0xFFC07A58);
  static const Color primarySoft = Color(0xFFF0E1D6);
  static const Color onPrimary = Color(0xFFFDF9F4);

  // 辅助莫兰迪色
  static const Color dustyBlue = Color(0xFF8D9AAF);
  static const Color dustyBlueSoft = Color(0xFFE6EAF0);
  static const Color sage = Color(0xFF93A48F);
  static const Color sageSoft = Color(0xFFE7ECE3);
  static const Color rose = Color(0xFFC1938F);
  static const Color roseSoft = Color(0xFFF0E3E1);

  // 周视图「生活痕迹」色阶（浅 → 深）
  static const Color traceZero = Color(0x00000000);
  static const Color traceOne = Color(0xFFF0E2D7);
  static const Color traceTwo = Color(0xFFDFC0AA);
  static const Color traceThree = Color(0xFFC68F72);

  // 语义色（低饱和，只做提示，不做大面积背景）
  static const Color error = Color(0xFFB98B8B);
  static const Color success = Color(0xFF8EA994);
  static const Color warning = Color(0xFFB5A078);

  // 图片等之上的暗色遮罩
  static const Color scrim = Color(0x99000000);

  // 大图查看（暖调近黑，不用纯黑纯白）
  static const Color viewerBackground = Color(0xFF211E1B);
  static const Color viewerForeground = Color(0xFFF3EEE6);
}

/// 标题使用的衬线字体：不打包字体文件，使用平台原生 serif。
/// 只用于少量标题（编辑物气质）；正文保持默认无衬线以保证可读性。
const String kSerifFamily = 'serif';

TextStyle serifStyle({
  double size = 20,
  FontWeight weight = FontWeight.w600,
  Color color = AppColors.textPrimary,
  double letterSpacing = 0.4,
  double height = 1.35,
}) =>
    TextStyle(
      fontFamily: kSerifFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );

/// 周视图活动密度色阶（同一暖色系深浅）：
/// 0 人 → 空；1 人 → 很浅；2 人 → 中等；3 人及以上 → 更明显。
Color weekActivityColor(int distinctMembers) {
  if (distinctMembers <= 0) return AppColors.traceZero;
  if (distinctMembers == 1) return AppColors.traceOne;
  if (distinctMembers == 2) return AppColors.traceTwo;
  return AppColors.traceThree;
}

/// V1 统一浅色主题（唯一主题入口；不做 Dark Mode / 换肤）。
ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.primary)
      .copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.dustyBlue,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.border,
    outlineVariant: AppColors.divider,
    error: AppColors.error,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: base.textTheme.copyWith(
      titleLarge: serifStyle(size: 21),
      titleMedium: serifStyle(size: 17, height: 1.3),
      titleSmall: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
        color: AppColors.textSecondary,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        height: 1.85,
        color: AppColors.textPrimary,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14.5,
        height: 1.7,
        color: AppColors.textPrimary,
      ),
      bodySmall: const TextStyle(
        fontSize: 12.5,
        height: 1.5,
        color: AppColors.textSecondary,
      ),
      labelSmall: const TextStyle(
        fontSize: 11,
        letterSpacing: 1.4,
        color: AppColors.textTertiary,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: kSerifFamily,
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: AppColors.textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 0.6),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 0.7,
      space: 1,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.textSecondary,
      textColor: AppColors.textPrimary,
      selectedColor: AppColors.textPrimary,
      selectedTileColor: AppColors.surfaceMuted,
      tileColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 8,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.6,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.textTertiary),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border, width: 0.8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surfaceMuted,
      selectedColor: AppColors.primarySoft,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimary,
      contentTextStyle:
          const TextStyle(color: AppColors.surface, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titleTextStyle: serifStyle(size: 17),
      contentTextStyle: const TextStyle(
        fontSize: 14.5,
        height: 1.7,
        color: AppColors.textSecondary,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppColors.primary),
    badgeTheme: const BadgeThemeData(
      backgroundColor: AppColors.primary,
      textColor: AppColors.onPrimary,
      smallSize: 7,
    ),
    iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),
  );
}
