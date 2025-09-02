/// Утилиты для безопасной работы с JSON
class JsonUtils {
  /// Безопасно извлекает строку из JSON
  static String getString(Map<String, dynamic> json, String key, [String defaultValue = '']) {
    final value = json[key];
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  /// Безопасно извлекает int из JSON
  static int getInt(Map<String, dynamic> json, String key, [int defaultValue = 0]) {
    final value = json[key];
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Безопасно извлекает bool из JSON
  static bool getBool(Map<String, dynamic> json, String key, [bool defaultValue = false]) {
    final value = json[key];
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    if (value is int) return value != 0;
    return defaultValue;
  }

  /// Безопасно извлекает DateTime из JSON
  static DateTime? getDateTime(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Безопасно извлекает DateTime из JSON с обязательным значением
  static DateTime getDateTimeRequired(Map<String, dynamic> json, String key) {
    final value = getDateTime(json, key);
    if (value == null) {
      throw FormatException('Missing or invalid DateTime for key: $key');
    }
    return value;
  }
}