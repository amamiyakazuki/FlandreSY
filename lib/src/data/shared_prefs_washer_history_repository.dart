import 'package:shared_preferences/shared_preferences.dart';

import 'recoverable_json.dart';
import 'washer_history_repository.dart';

class SharedPrefsWasherHistoryRepository implements WasherHistoryRepository {
  static const String _snapshotKey = 'washer_order_snapshot_json';
  static const String _oldHistoryKey = 'washer_history_json';

  @override
  Future<WasherSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.containsKey(_snapshotKey) ? _snapshotKey : _oldHistoryKey;
    return readRecoverableJson(prefs, key, WasherHistoryCodec.decode);
  }

  @override
  Future<void> save(WasherSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
        _snapshotKey, WasherHistoryCodec.encode(snapshot));
    if (!saved) throw StateError('洗衣订单保存失败');
  }
}
