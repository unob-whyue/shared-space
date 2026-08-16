import 'package:flutter/material.dart';

/// 用户个人标注颜色（docs/DATABASE.md §2：预设 color_key，不允许任意 HEX）。
/// 数据库只存 key；UI 按本表映射实际颜色。
/// Milestone 3：8 个预设色全部改为浅色、低饱和、彼此易区分的莫兰迪色；
/// key 保持不变（兼容已有数据与 DB 默认值 'blue'）。
class ColorKeyDef {
  const ColorKeyDef(this.key, this.color);

  final String key;
  final Color color;
}

const List<ColorKeyDef> kProfileColorKeys = [
  ColorKeyDef('blue', Color(0xFF8D9AAF)), // 灰蓝 dustyBlue
  ColorKeyDef('green', Color(0xFF8EA994)), // 鼠尾草 sage
  ColorKeyDef('orange', Color(0xFFC4A484)), // 灰橘 mutedOrange
  ColorKeyDef('red', Color(0xFFB98B8B)), // 灰玫瑰 dustyRose
  ColorKeyDef('purple', Color(0xFF9D94B8)), // 灰紫 softLavender
  ColorKeyDef('pink', Color(0xFFC29AA3)), // 灰粉 softMauve
  ColorKeyDef('teal', Color(0xFF87A6A3)), // 灰青 dustyTeal
  ColorKeyDef('brown', Color(0xFFA9968A)), // 灰棕 softBrown
];

Color colorForKey(String key) => kProfileColorKeys
    .firstWhere((c) => c.key == key, orElse: () => kProfileColorKeys.first)
    .color;

bool isValidColorKey(String key) =>
    kProfileColorKeys.any((c) => c.key == key);
