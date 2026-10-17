import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../runtime/diagnostic_privacy.dart';
import 'diagnostic_log_repository.dart';

/// A single-key envelope replaces legacy raw logs atomically. No extra marker
/// or backup can claim migration succeeded before the old text is erased.
class SharedPrefsDiagnosticLogRepository implements DiagnosticLogRepository {
  static const String _logKey = 'diagnostic_log';

  @override
  Future<String> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.get(_logKey);
    if (raw == null) return '';
    if (raw is! String) {
      await save('');
      return '';
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {/* legacy text */}
    if (decoded is Map &&
        decoded['diagnosticSchema'] == 1 &&
        decoded['text'] is String) {
      final safe = DiagnosticPrivacy.history(decoded['text'] as String);
      if (safe != decoded['text']) await save(safe);
      return safe;
    }
    await save(
        ''); // First upgrade: clear diagnostics only, never business keys.
    return '';
  }

  @override
  Future<void> save(String log) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final ok = await prefs.setString(
          _logKey,
          jsonEncode({
            'diagnosticSchema': 1,
            'text': DiagnosticPrivacy.history(log),
          }));
      if (!ok) throw StateError('diagnostic storage rejected write');
    } catch (_) {
      await prefs
          .reload(); // Discard optimistic plugin cache after failed write.
      rethrow;
    }
  }
}
