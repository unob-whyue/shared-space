// 批注选区纯函数（可单测）。
// 选区语义：start_offset/end_offset 为正文的 UTF-16 code unit 下标，
// [start, end) 左闭右开；selected_text 用于校验正文修改（无版本控制）。

/// 一条正文切片：无批注处 annotationIndex 为 null。
class AnnotationSegment {
  const AnnotationSegment({
    required this.start,
    required this.end,
    this.annotationIndex,
  });

  final int start;
  final int end;

  /// annotations 列表中的下标；null = 无批注覆盖。
  final int? annotationIndex;
}

/// 批注选区在当前正文中是否仍有效。
/// 正文被修改后（边界越界或原文不匹配）→ false → UI 显示「原文已修改」。
bool annotationIsValid(String text, Map<String, dynamic> annotation) {
  final start = annotation['start_offset'];
  final end = annotation['end_offset'];
  final selected = annotation['selected_text'];
  if (start is! int || end is! int || selected is! String) return false;
  if (start < 0 || end <= start || end > text.length) return false;
  return text.substring(start, end) == selected;
}

/// 把正文切分为连续片段（覆盖全文）。
/// 重叠选区由列表中靠前（= 创建更早）的批注着色（先到先得）；
/// 无效批注被忽略（由调用方在卡片中以「原文已修改」展示）。
List<AnnotationSegment> buildAnnotationSegments(
  String text,
  List<Map<String, dynamic>> annotations,
) {
  final valid = <(int, int, int)>[];
  for (var i = 0; i < annotations.length; i++) {
    if (!annotationIsValid(text, annotations[i])) continue;
    valid.add((
      annotations[i]['start_offset'] as int,
      annotations[i]['end_offset'] as int,
      i,
    ));
  }
  if (valid.isEmpty) {
    return [AnnotationSegment(start: 0, end: text.length)];
  }

  final boundaries = <int>{0, text.length};
  for (final (start, end, _) in valid) {
    boundaries.add(start);
    boundaries.add(end);
  }
  final sorted = boundaries.toList()..sort();

  final segments = <AnnotationSegment>[];
  for (var i = 0; i < sorted.length - 1; i++) {
    final segStart = sorted[i];
    final segEnd = sorted[i + 1];
    if (segStart >= segEnd) continue;
    int? covering;
    for (final (start, end, index) in valid) {
      if (start <= segStart && segEnd <= end) {
        covering = index;
        break;
      }
    }
    segments.add(AnnotationSegment(
      start: segStart,
      end: segEnd,
      annotationIndex: covering,
    ));
  }
  return segments;
}
