// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// SharedPreferences-backed DiagnosticLogRepository (no visual constants). Stores the whole rolling
// log buffer as one string under a single key (mirrors legacy AppLogStore's "logs" pref key).

import 'package:shared_preferences/shared_preferences.dart';

import 'diagnostic_log_repository.dart';

/// 基于 shared_preferences 的诊断日志持久化实现（Android + iOS）。
class SharedPrefsDiagnosticLogRepository implements DiagnosticLogRepository {
  SharedPrefsDiagnosticLogRepository();

  static const String _logKey = 'diagnostic_log';

  @override
  Future<String> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_logKey) ?? '';
  }

  @override
  Future<void> save(String log) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_logKey, log);
  }
}
