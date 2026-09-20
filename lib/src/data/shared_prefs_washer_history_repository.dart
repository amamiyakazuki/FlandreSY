import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../runtime/models/washer_order.dart';
import 'washer_history_repository.dart';

class SharedPrefsWasherHistoryRepository implements WasherHistoryRepository {
  static const String _historyKey = 'washer_history_json';
  static const String _snapshotKey = 'washer_order_snapshot_json';

  @override
  Future<List<WasherOrderHistoryUi>?> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = prefs.getString(_snapshotKey);
    if (snapshot != null) {
      final decoded = jsonDecode(snapshot) as Map;
      return WasherHistoryCodec.decode(jsonEncode(decoded['history']));
    }
    if (!prefs.containsKey(_historyKey)) return null;
    return WasherHistoryCodec.decode(prefs.getString(_historyKey) ?? '');
  }

  @override
  Future<void> saveHistory(List<WasherOrderHistoryUi> history) async {
    await saveSnapshot(
        currentOrder: await loadCurrentOrder(), history: history);
  }

  @override
  Future<WasherOrderUi?> loadCurrentOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_snapshotKey);
    if (raw == null) {
      return WasherHistoryCodec.legacyCandidate(
          await loadHistory() ?? const []);
    }
    final current = (jsonDecode(raw) as Map)['currentOrder'];
    if (current != null && current is! Map) {
      throw const FormatException('洗衣活动订单损坏');
    }
    return current is Map
        ? WasherHistoryCodec.orderFromMap(current)
        : WasherHistoryCodec.legacyCandidate(await loadHistory() ?? const []);
  }

  @override
  Future<void> saveSnapshot(
      {WasherOrderUi? currentOrder,
      required List<WasherOrderHistoryUi> history}) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
        _snapshotKey,
        jsonEncode({
          'currentOrder': currentOrder == null
              ? null
              : WasherHistoryCodec.orderToMap(currentOrder),
          'history': jsonDecode(WasherHistoryCodec.encode(history)),
        }));
    if (!saved) throw StateError('洗衣订单保存失败');
  }
}
