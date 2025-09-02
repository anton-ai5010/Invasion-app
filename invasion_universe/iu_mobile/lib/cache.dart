import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Cache {
  static Future<void> setJson(String key, Object value, {Duration ttl = const Duration(minutes: 10)}) async {
    final sp = await SharedPreferences.getInstance();
    final payload = {
      'expiresAt': DateTime.now().add(ttl).toIso8601String(),
      'data': value,
    };
    await sp.setString(key, json.encode(payload));
  }

  static Future<Map<String, dynamic>?> getJson(String key) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(key);
    if (raw == null) return null;
    try {
      final m = json.decode(raw) as Map<String, dynamic>;
      final expiresAtValue = m['expiresAt'];
      final exp = (expiresAtValue is String) 
          ? DateTime.tryParse(expiresAtValue) ?? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0);
      if (DateTime.now().isAfter(exp)) {
        await sp.remove(key);
        return null;
      }
      final data = m['data'];
      return (data is Map<String, dynamic>) ? data : {'_list': data};
    } catch (_) {
      await sp.remove(key);
      return null;
    }
  }

  static Future<void> remove(String key) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(key);
  }
}