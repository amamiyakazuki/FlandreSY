import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 读取失败时保留原件并备份；由 bootstrap 单域降级并展示告警。
Future<T?> readRecoverableJson<T>(
    SharedPreferences prefs, String key, T Function(String raw) decode) async {
  if (!prefs.containsKey(key)) return null;
  try {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      throw const FormatException('Empty stored JSON');
    }
    return decode(raw);
  } catch (_) {
    final backupKey = '${key}_recovery_backup';
    if (!prefs.containsKey(backupKey)) {
      final value = prefs.get(key);
      final raw = value is String ? value : jsonEncode(value);
      if (!await prefs.setString(backupKey, raw)) throw StateError('恢复备份保存失败');
    }
    rethrow;
  }
}
