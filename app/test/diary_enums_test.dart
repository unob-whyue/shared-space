import 'package:flutter_test/flutter_test.dart';
import 'package:shared_space_app/features/diary/diary_enums.dart';
import 'package:shared_space_app/features/diary/diary_repository.dart';

/// 纯逻辑单元测试（无网络）。
void main() {
  group('天气枚举', () {
    test('key 与 storageValue 一一对应', () {
      expect(WeatherKey.values.map((w) => w.storageValue).toSet().length,
          WeatherKey.values.length);
    });

    test('未知 key 回退为 unknown', () {
      expect(WeatherKeyX.fromStorage('typhoon'), WeatherKey.unknown);
      expect(WeatherKeyX.fromStorage('sunny'), WeatherKey.sunny);
    });

    test('每个枚举都有中文名', () {
      expect(WeatherKey.values.every((w) => w.label.isNotEmpty), isTrue);
    });
  });

  group('心情枚举', () {
    test('key 与 storageValue 一一对应', () {
      expect(MoodKey.values.map((m) => m.storageValue).toSet().length,
          MoodKey.values.length);
    });

    test('未知 key 回退为 calm', () {
      expect(MoodKeyX.fromStorage('whatever'), MoodKey.calm);
      expect(MoodKeyX.fromStorage('love'), MoodKey.love);
    });
  });

  group('日期格式化', () {
    test('diary_date 格式为 YYYY-MM-DD', () {
      expect(formatDiaryDate(DateTime(2026, 8, 10)), '2026-08-10');
      expect(formatDiaryDate(DateTime(2026, 1, 2)), '2026-01-02');
    });
  });
}
