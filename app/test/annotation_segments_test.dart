import 'package:flutter_test/flutter_test.dart';
import 'package:shared_space_app/features/annotation/annotation_segments.dart';

Map<String, dynamic> anno(int start, int end, String selected) => {
      'start_offset': start,
      'end_offset': end,
      'selected_text': selected,
      'id': 'a$start$end',
      'created_at': '2026-08-16T00:00:00Z',
    };

void main() {
  const text = '今天去了图书馆，读完了一本很喜欢的书。';

  group('annotationIsValid', () {
    test('原文匹配且边界合法 → 有效', () {
      expect(annotationIsValid(text, anno(4, 7, '图书馆')), isTrue);
    });

    test('原文被修改 → 无效', () {
      expect(annotationIsValid(text, anno(4, 7, '博物馆')), isFalse);
    });

    test('越界 → 无效', () {
      expect(annotationIsValid(text, anno(4, 99, '图书馆')), isFalse);
      expect(annotationIsValid(text, anno(-1, 7, '图书馆')), isFalse);
      expect(annotationIsValid(text, anno(7, 4, '图书馆')), isFalse);
    });

    test('字段类型缺失 → 无效', () {
      expect(annotationIsValid(text, {}), isFalse);
    });
  });

  group('buildAnnotationSegments', () {
    test('无批注 → 单一全文片段', () {
      final segments = buildAnnotationSegments(text, []);
      expect(segments.length, 1);
      expect(segments.first.start, 0);
      expect(segments.first.end, text.length);
      expect(segments.first.annotationIndex, isNull);
    });

    test('两条不重叠批注 → 片段连续且各自着色', () {
      final annotations = [anno(4, 7, '图书馆'), anno(8, 10, '读完')];
      final segments = buildAnnotationSegments(text, annotations);
      // 覆盖全文且首尾相接
      expect(segments.first.start, 0);
      expect(segments.last.end, text.length);
      for (var i = 0; i < segments.length - 1; i++) {
        expect(segments[i].end, segments[i + 1].start);
      }
      final covered = segments
          .where((s) => s.annotationIndex != null)
          .map((s) => s.annotationIndex)
          .toSet();
      expect(covered, {0, 1});
    });

    test('重叠选区 → 靠前的批注（先到先得）着色', () {
      final annotations = [anno(4, 9, '图书馆，读'), anno(6, 10, '馆，读完')];
      final segments = buildAnnotationSegments(text, annotations);
      // 交集 [6,9) 归属 index 0
      final overlap = segments.firstWhere((s) => s.start == 6 && s.end == 9);
      expect(overlap.annotationIndex, 0);
      // [9,10) 归属 index 1
      final tail = segments.firstWhere((s) => s.start == 9 && s.end == 10);
      expect(tail.annotationIndex, 1);
    });

    test('无效批注被忽略（其余正常着色）', () {
      final annotations = [anno(4, 7, '博物馆'), anno(8, 10, '读完')];
      final segments = buildAnnotationSegments(text, annotations);
      final covered = segments
          .where((s) => s.annotationIndex != null)
          .map((s) => s.annotationIndex)
          .toSet();
      expect(covered, {1});
    });

    test('空正文', () {
      expect(buildAnnotationSegments('', []).length, 1);
      expect(buildAnnotationSegments('', [anno(0, 1, 'x')]).first.annotationIndex,
          isNull);
    });
  });
}
