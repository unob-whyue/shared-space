// 天气 / 心情 固定枚举（docs/DATABASE.md §8）。
// 数据库只存 key；UI 显示中文名。

enum WeatherKey {
  sunny,
  partlyCloudy,
  cloudy,
  rain,
  storm,
  snow,
  fog,
  unknown,
}

extension WeatherKeyX on WeatherKey {
  String get storageValue => switch (this) {
        WeatherKey.sunny => 'sunny',
        WeatherKey.partlyCloudy => 'partly_cloudy',
        WeatherKey.cloudy => 'cloudy',
        WeatherKey.rain => 'rain',
        WeatherKey.storm => 'storm',
        WeatherKey.snow => 'snow',
        WeatherKey.fog => 'fog',
        WeatherKey.unknown => 'unknown',
      };

  String get label => switch (this) {
        WeatherKey.sunny => '晴',
        WeatherKey.partlyCloudy => '多云',
        WeatherKey.cloudy => '阴',
        WeatherKey.rain => '雨',
        WeatherKey.storm => '雷雨',
        WeatherKey.snow => '雪',
        WeatherKey.fog => '雾',
        WeatherKey.unknown => '未知',
      };

  static WeatherKey fromStorage(String value) =>
      WeatherKey.values.firstWhere((w) => w.storageValue == value,
          orElse: () => WeatherKey.unknown);
}

enum MoodKey { happy, calm, sad, angry, excited, tired, anxious, love }

extension MoodKeyX on MoodKey {
  String get storageValue => switch (this) {
        MoodKey.happy => 'happy',
        MoodKey.calm => 'calm',
        MoodKey.sad => 'sad',
        MoodKey.angry => 'angry',
        MoodKey.excited => 'excited',
        MoodKey.tired => 'tired',
        MoodKey.anxious => 'anxious',
        MoodKey.love => 'love',
      };

  String get label => switch (this) {
        MoodKey.happy => '开心',
        MoodKey.calm => '平静',
        MoodKey.sad => '难过',
        MoodKey.angry => '生气',
        MoodKey.excited => '兴奋',
        MoodKey.tired => '疲惫',
        MoodKey.anxious => '焦虑',
        MoodKey.love => '爱',
      };

  static MoodKey fromStorage(String value) =>
      MoodKey.values.firstWhere((m) => m.storageValue == value,
          orElse: () => MoodKey.calm);
}
