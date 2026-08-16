import 'package:flutter_test/flutter_test.dart';
import 'package:shared_space_app/features/diary/diary_image_repository.dart';

/// 图片上限必须集中定义（UI_SPEC.md §13）。
void main() {
  test('单篇日记图片上限为 9 张（集中定义）', () {
    expect(kMaxDiaryImages, 9);
  });
}
