// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Diagnostic log persistence abstraction (no visual constants). Same decoupling pattern as
// SettingsRepository / HistoryRepository / WaterOrderRepository (roadmap §3: keep persistence out
// of the runtime, inject via interface). M-REAL 日志与诊断：the whole rolling log buffer is stored
// as one string (mirrors legacy AppLogStore's single "logs" pref key).

/// 诊断日志持久化接口（M-REAL）。整块日志字符串存/取（对齐 legacy AppLogStore 单 key）。
/// [load] 返回空串表示「无日志」（首启或清空后）。
abstract class DiagnosticLogRepository {
  Future<String> load();
  Future<void> save(String log);
}

/// 内存实现：默认兜底 + 测试注入用。无 IO、无平台依赖。
class InMemoryDiagnosticLogRepository implements DiagnosticLogRepository {
  InMemoryDiagnosticLogRepository({String initial = ''}) : _log = initial;

  String _log;

  @override
  Future<String> load() async => _log;

  @override
  Future<void> save(String log) async => _log = log;
}
