import 'package:shared_preferences/shared_preferences.dart';

import '../runtime/models/hotwater_history.dart';
import 'history_repository.dart';
import 'recoverable_json.dart';

/// 基于 shared_preferences 的热水历史持久化实现（Android + iOS）。
class SharedPrefsHistoryRepository implements HistoryRepository {
  SharedPrefsHistoryRepository();

  static const String _historyKey = 'hotwater_history_json';

  @override
  Future<List<HotwaterHistoryUi>?> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    // key 不存在为 null；已有空列表和旧记录均按存储恢复。
    if (!prefs.containsKey(_historyKey)) {
      return null;
    }
    return readRecoverableJson(prefs, _historyKey, HotwaterHistoryCodec.decode);
  }

  @override
  Future<void> saveHistory(List<HotwaterHistoryUi> history) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (!await prefs.setString(
          _historyKey, HotwaterHistoryCodec.encode(history))) {
        throw StateError('热水历史保存失败');
      }
    } catch (_) {
      await prefs.reload();
      rethrow;
    }
  }
}
