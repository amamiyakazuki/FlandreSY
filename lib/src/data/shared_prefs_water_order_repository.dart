// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// SharedPreferences-backed WaterOrderRepository (no visual constants). Stores the whole water-order
// snapshot (current order + history) as one JSON string under a single key (mirrors
// SharedPrefsHistoryRepository / SharedPrefsLocalDeviceRepository). Key presence distinguishes
// "never persisted" (null → first-launch, no water data) from persisted user data.

import 'package:shared_preferences/shared_preferences.dart';

import 'water_order_repository.dart';

/// 基于 shared_preferences 的饮水订单持久化实现（Android + iOS）。PWATER（问题7）。
class SharedPrefsWaterOrderRepository implements WaterOrderRepository {
  SharedPrefsWaterOrderRepository();

  static const String _waterKey = 'water_order_snapshot_json';

  @override
  Future<WaterOrderSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    // key 不存在 = 从未持久化过 → null（首启无饮水数据）；存在 = 用户数据。
    if (!prefs.containsKey(_waterKey)) {
      return null;
    }
    final json = prefs.getString(_waterKey) ?? '';
    return WaterOrderCodec.decode(json);
  }

  @override
  Future<void> save(WaterOrderSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_waterKey, WaterOrderCodec.encode(snapshot));
  }
}
