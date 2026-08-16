import 'package:flutter_test/flutter_test.dart';
import 'package:shared_space_app/features/profile/color_keys.dart';
import 'package:shared_space_app/features/profile/profile_rules.dart';

void main() {
  group('昵称校验', () {
    test('空昵称不合法', () {
      expect(validateNickname(''), '昵称不能为空');
      expect(validateNickname('   '), '昵称不能为空');
    });

    test('超长昵称不合法', () {
      expect(validateNickname('长' * 21), '昵称最多 20 个字符');
      expect(validateNickname('长' * 20), isNull);
    });

    test('合法昵称通过并去除首尾空白语义', () {
      expect(validateNickname('吴玥'), isNull);
    });
  });

  group('邀请码', () {
    test('normalize 去空白转大写', () {
      expect(normalizeInviteCode(' ab12cd34 '), 'AB12CD34');
    });

    test('格式校验：8 位大写字母数字', () {
      expect(isValidInviteCodeFormat('AB12CD34'), isTrue);
      expect(isValidInviteCodeFormat('AB12CD3'), isFalse);
      expect(isValidInviteCodeFormat('AB12CD3!'), isFalse);
      expect(isValidInviteCodeFormat('ab12cd34'), isFalse, reason: '须先 normalize');
    });
  });

  group('空间名称校验', () {
    test('空名称不合法', () {
      expect(validateSpaceName(''), '空间名称不能为空');
    });

    test('超长不合法', () {
      expect(validateSpaceName('名' * 31), '空间名称最多 30 个字符');
      expect(validateSpaceName('名' * 30), isNull);
    });
  });

  group('颜色调色板', () {
    test('颜色 key 唯一且都可显示', () {
      final keys = kProfileColorKeys.map((c) => c.key).toList();
      expect(keys.toSet().length, keys.length);
      expect(kProfileColorKeys.length, 8);
      for (final def in kProfileColorKeys) {
        expect(colorForKey(def.key), def.color);
        expect(isValidColorKey(def.key), isTrue);
      }
    });

    test('未知 key 回退到第一个颜色', () {
      expect(colorForKey('nope'), kProfileColorKeys.first.color);
      expect(isValidColorKey('nope'), isFalse);
    });
  });
}
