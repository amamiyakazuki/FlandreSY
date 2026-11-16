// SharedPreferences-backed WaterOrderRepository (no visual constants). Stores the whole water-order
// snapshot (current order + history) as one JSON string under a single key (mirrors
// SharedPrefsHistoryRepository / SharedPrefsLocalDeviceRepository). Key presence distinguishes
// "never persisted" (null → first-launch, no water data) from persisted user data.

import 'package:shared_preferences/shared_preferences.dart';

import 'recoverable_json.dart';
import 'water_order_repository.dart';

/// 基于 shared_preferences 的饮水订单持久化实现（Android + iOS）。PWATER（问题7）。
class SharedPrefsWaterOrderRepository implements WaterOrderRepository {
  SharedPrefsWaterOrderRepository();

  static const String _waterKey = 'water_order_snapshot_json';

  @override
  Future<WaterOrderSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return readRecoverableJson(prefs, _waterKey, WaterOrderCodec.decode);
  }

  @override
  Future<void> save(WaterOrderSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final saved =
        await prefs.setString(_waterKey, WaterOrderCodec.encode(snapshot));
    if (!saved) throw StateError('饮水订单保存失败');
  }
}
