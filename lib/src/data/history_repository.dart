// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Hotwater history persistence abstraction (no visual constants). Same decoupling pattern as
// LocalDeviceRepository (PDEV) / AccountSessionRepository. PHIST: the hotwater history list
// (state.hotwater.history) previously lived only in memory (adapter-fetched + live start/stop
// appends); now it round-trips through this repository.

import 'dart:convert';

import '../runtime/models/hotwater_history.dart';

/// 热水历史持久化接口（PHIST）。与 [LocalDeviceRepository] 同构。
///
/// [loadHistory] 返回 null 表示「从未持久化过」（首启 → 走 adapter 拉取）；返回 `[]` 表示
/// 「空历史」（恢复空，不再拉取——对齐 loadHotwaterHistory「非空则跳过」的现有语义）。
abstract class HistoryRepository {
  Future<List<HotwaterHistoryUi>?> loadHistory();
  Future<void> saveHistory(List<HotwaterHistoryUi> history);
}

/// 热水历史 JSON 编解码（对齐 [HotwaterHistoryUi] 全字段，全 String required）。
/// 抽成静态供 SharedPrefs 实现 + fixture 直用。
class HotwaterHistoryCodec {
  const HotwaterHistoryCodec._();

  static String encode(List<HotwaterHistoryUi> history) {
    return jsonEncode(history.map(toMap).toList());
  }

  static List<HotwaterHistoryUi> decode(String json) {
    if (json.isEmpty) {
      return const <HotwaterHistoryUi>[];
    }
    final decoded = jsonDecode(json);
    if (decoded is! List) {
      return const <HotwaterHistoryUi>[];
    }
    final out = <HotwaterHistoryUi>[];
    for (final item in decoded) {
      if (item is Map) {
        out.add(fromMap(item.cast<String, dynamic>()));
      }
    }
    return out;
  }

  static Map<String, dynamic> toMap(HotwaterHistoryUi h) {
    return <String, dynamic>{
      'time': h.time,
      'deviceId': h.deviceId,
      'amount': h.amount,
      'status': h.status,
      'orderId': h.orderId,
    };
  }

  static HotwaterHistoryUi fromMap(Map<String, dynamic> m) {
    return HotwaterHistoryUi(
      time: (m['time'] ?? '').toString(),
      deviceId: (m['deviceId'] ?? '').toString(),
      amount: (m['amount'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      orderId: (m['orderId'] ?? '').toString(),
    );
  }
}

/// 内存实现：默认兜底 + 测试注入用。无 IO、无平台依赖。
/// 传入非 null [history] 即模拟「已持久化」（loadHistory 返回该列表）。
class InMemoryHistoryRepository implements HistoryRepository {
  InMemoryHistoryRepository({List<HotwaterHistoryUi>? history})
      : _history = history;

  List<HotwaterHistoryUi>? _history;

  @override
  Future<List<HotwaterHistoryUi>?> loadHistory() async => _history;

  @override
  Future<void> saveHistory(List<HotwaterHistoryUi> history) async =>
      _history = List<HotwaterHistoryUi>.of(history);
}
