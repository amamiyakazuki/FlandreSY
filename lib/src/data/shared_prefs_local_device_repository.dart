// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// SharedPreferences-backed LocalDeviceRepository (no visual constants). Stores the whole device list
// as one JSON string under a single key (mirrors saveShower798's list-as-JSON pattern). Uses the
// key's presence to distinguish "never persisted" (null → first-launch empty) from "user emptied
// the list" ([] → restore empty, never re-seed).

import 'package:shared_preferences/shared_preferences.dart';

import '../runtime/models/local_device.dart';
import 'local_device_repository.dart';

/// 基于 shared_preferences 的本地设备列表持久化实现（Android + iOS）。
class SharedPrefsLocalDeviceRepository implements LocalDeviceRepository {
  SharedPrefsLocalDeviceRepository();

  static const String _devicesKey = 'local_devices_json';

  @override
  Future<List<LocalDeviceShortcut>?> loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    // key 不存在 = 从未持久化过 → null（首启空列表起步）；存在（含空 JSON）= 用户数据。
    if (!prefs.containsKey(_devicesKey)) {
      return null;
    }
    final json = prefs.getString(_devicesKey) ?? '';
    return LocalDeviceCodec.decode(json);
  }

  @override
  Future<void> saveDevices(List<LocalDeviceShortcut> devices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_devicesKey, LocalDeviceCodec.encode(devices));
  }
}
