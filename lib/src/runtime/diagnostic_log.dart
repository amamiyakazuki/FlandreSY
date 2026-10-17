import 'dart:async';
import 'package:flutter/foundation.dart';

import '../data/diagnostic_log_repository.dart';
import 'diagnostic_privacy.dart';
import 'live_clock.dart';

/// Ordered, bounded diagnostics. Storage errors are status, never log events.
class DiagnosticLog extends ChangeNotifier {
  DiagnosticLog({required DiagnosticLogRepository repo, LiveClock? clock})
      : _repo = repo,
        _clock = clock ?? const SystemLiveClock() {
    ready = _restore();
    _tail = ready;
  }

  static const int maxChars = 16000;
  final DiagnosticLogRepository _repo;
  final LiveClock _clock;
  final List<({int sequence, String text})> _entries = [];
  int _sequence = 0;
  bool _clearRequested = false;
  bool _disposed = false;
  String? storageError;
  late final Future<void> ready;
  Future<void> _tail = Future<void>.value();

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _restore() async {
    try {
      final stored = DiagnosticPrivacy.history(await _repo.load());
      if (!_clearRequested && stored.isNotEmpty) {
        _entries.insertAll(
            0,
            stored
                .split('\n')
                .where((line) => line.isNotEmpty)
                .map((line) => (sequence: 0, text: '$line\n')));
        _trim();
      }
      storageError = null;
    } catch (_) {
      storageError = '诊断历史读取或清理未完成，请重试';
    }
    _changed();
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _tail.then((_) => action());
    // Keep the queue alive, while returning the actual result to clear/retry.
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  Future<void> _save(String value) async {
    try {
      await _repo.save(DiagnosticPrivacy.history(value));
      storageError = null;
    } catch (_) {
      storageError = '诊断保存未完成，请重试';
      rethrow;
    } finally {
      _changed();
    }
  }

  void log(String tag, String message) {
    _entries.add((
      sequence: ++_sequence,
      text:
          '[${_timestamp()}] [${DiagnosticPrivacy.tag(tag)}] ${DiagnosticPrivacy.message(message)}\n'
    ));
    _trim();
    _changed();
    unawaited(_enqueue(() => _save(read())).catchError((Object _) {}));
  }

  void _trim() {
    var total = _entries.fold<int>(0, (sum, entry) => sum + entry.text.length);
    while (total > maxChars && _entries.isNotEmpty) {
      total -= _entries.removeAt(0).text.length;
    }
  }

  String read() =>
      DiagnosticPrivacy.history(_entries.map((entry) => entry.text).join());

  /// Cut at invocation time, commit only after persistence. Events produced
  /// after this boundary survive; later queued saves compute the current buffer.
  Future<void> clear() {
    _clearRequested = true;
    final boundary = _sequence;
    return _enqueue(() async {
      final retained = _entries
          .where((entry) => entry.sequence > boundary)
          .map((entry) => entry.text)
          .join();
      await _save(retained);
      _entries.removeWhere((entry) => entry.sequence <= boundary);
      _changed();
    });
  }

  Future<void> retryStorage() => _enqueue(() async {
        try {
          // Also retries a failed legacy-log migration; never expose its raw text.
          await _repo.load();
          await _save(read());
        } catch (_) {
          storageError = '诊断存储未恢复，请重试';
          _changed();
          rethrow;
        }
      });

  Future<void> flush() => _tail;
  void Function(String message) sinkFor(String tag) =>
      (message) => log(tag, message);

  String _timestamp() {
    final dt = DateTime.fromMillisecondsSinceEpoch(_clock.nowMillis());
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
