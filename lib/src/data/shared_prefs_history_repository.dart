// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// SharedPreferences-backed HistoryRepository (no visual constants). Stores the whole hotwater history
// list as one JSON string under a single key (mirrors SharedPrefsLocalDeviceRepository). Uses the
// key's presence to distinguish "never persisted" (null → first-launch adapter fetch) from "empty
// history" ([] → restore empty, skip fetch).

import 'package:shared_preferences/shared_preferences.dart';

import '../runtime/models/hotwater_history.dart';
import 'history_repository.dart';

/// 基于 shared_preferences 的热水历史持久化实现（Android + iOS）。
class SharedPrefsHistoryRepository implements HistoryRepository {
  SharedPrefsHistoryRepository();

  static const String _historyKey = 'hotwater_history_json';

  @override
  Future<List<HotwaterHistoryUi>?> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    // key 不存在 = 从未持久化过 → null（首启走 adapter 拉取）；存在（含空 JSON）= 用户数据。
    if (!prefs.containsKey(_historyKey)) {
      return null;
    }
    final json = prefs.getString(_historyKey) ?? '';
    return HotwaterHistoryCodec.decode(json);
  }

  @override
  Future<void> saveHistory(List<HotwaterHistoryUi> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, HotwaterHistoryCodec.encode(history));
  }
}
