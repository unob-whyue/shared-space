import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// 客户端压缩（UI_SPEC.md §13：选择 → 压缩 → 上传）。
/// 统一输出 JPEG；最长边 ≤ [maxDimension]，质量 [quality]。
Future<Uint8List> compressDiaryImage(
  Uint8List original, {
  int maxDimension = 1600,
  int quality = 80,
}) async {
  final result = await FlutterImageCompress.compressWithList(
    original,
    minWidth: maxDimension,
    minHeight: maxDimension,
    quality: quality,
    format: CompressFormat.jpeg,
  );
  return result;
}
