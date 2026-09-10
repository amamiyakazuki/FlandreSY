import 'package:shared_preferences/shared_preferences.dart';

import '../runtime/models/washer_order.dart';
import 'washer_history_repository.dart';

class SharedPrefsWasherHistoryRepository implements WasherHistoryRepository {
  static const String _historyKey = 'washer_history_json';

  @override
  Future<List<WasherOrderHistoryUi>?> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_historyKey)) return null;
    return WasherHistoryCodec.decode(prefs.getString(_historyKey) ?? '');
  }

  @override
  Future<void> saveHistory(List<WasherOrderHistoryUi> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, WasherHistoryCodec.encode(history));
  }
}
