// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Runtime diagnostic logger (no visual constants). M-REAL 日志与诊断: an in-memory rolling buffer
// (capped like legacy AppLogStore.MAX_CHARS = 16000 chars, head-trimmed) that also persists through
// an injected DiagnosticLogRepository. Real adapters get a per-tag sink (mirrors legacy
// `message -> AppLogStore.append(ctx, "[tag] " + message)`); the log screen reads read().

import 'dart:async';

import '../data/diagnostic_log_repository.dart';
import 'live_clock.dart';

/// 诊断日志器（M-REAL）。内存缓冲 + 持久化后端；超上限裁头（环形，对齐 legacy 16000 字）。
/// 各真实 adapter 通过 [sinkFor] 拿到带 tag 的写入闭包；日志页读 [read]。
class DiagnosticLog {
  DiagnosticLog({
    required DiagnosticLogRepository repo,
    LiveClock? clock,
  })  : _repo = repo,
        _clock = clock ?? const SystemLiveClock() {
    // 载入已持久化的缓冲（fire-and-forget；首次读时可能尚未回填，可接受）。
    unawaited(_restore());
  }

  /// 最大字符数（对齐 legacy AppLogStore.MAX_CHARS）。超出裁掉最旧的头部。
  static const int maxChars = 16000;

  final DiagnosticLogRepository _repo;
  final LiveClock _clock;
  final StringBuffer _buffer = StringBuffer();

  Future<void> _restore() async {
    if (_buffer.isNotEmpty) {
      return; // 已有运行期日志，别用旧盘覆盖。
    }
    final persisted = await _repo.load();
    if (persisted.isNotEmpty && _buffer.isEmpty) {
      _buffer.write(persisted);
    }
  }

  /// 追加一行 `[HH:mm:ss] [tag] message`。超上限裁头后持久化（fire-and-forget）。
  void log(String tag, String message) {
    final line = '[${_timestamp()}] [$tag] $message\n';
    var merged = _buffer.toString() + line;
    if (merged.length > maxChars) {
      merged = merged.substring(merged.length - maxChars);
    }
    _buffer
      ..clear()
      ..write(merged);
    unawaited(_repo.save(merged));
  }

  /// 当前完整日志（供日志页显示 / 复制）。
  String read() => _buffer.toString();

  /// 清空日志（内存 + 持久化）。对齐 legacy AppLogStore.clear。
  void clear() {
    _buffer.clear();
    unawaited(_repo.save(''));
  }

  /// 给指定 tag 的写入闭包，供真实 adapter 注入（对齐 legacy per-runtime logger）。
  void Function(String message) sinkFor(String tag) =>
      (message) => log(tag, message);

  /// 毫秒时间戳 → `HH:mm:ss` 本地时间（比 formatClockTime 多秒精度，日志需要）。
  String _timestamp() {
    final dt = DateTime.fromMillisecondsSinceEpoch(_clock.nowMillis());
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
