import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../runtime/hotwater_state.dart';
import 'water_order_repository.dart';
import 'history_repository.dart';
import 'washer_history_repository.dart';

/// C1 的本地保全日志。仅包含普通存储；永不读取或复制安全仓库。
abstract class LegacyMigrationStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<Map<String, Object>> readLegacyValues();
}

class SharedPrefsLegacyMigrationStore implements LegacyMigrationStore {
  static const legacyKeys = {
    'use_simulated_backend',
    'bath_system_preference',
    'permission_intro_seen',
    'zhuli_phone',
    'zhuli_device_code',
    'ujing_mobile',
    'ujing_user_id',
    'ujing_service_subject_id',
    'shower798_snapshot_v2',
    'shower798_mobile',
    'shower798_uid',
    'shower798_eid',
    'shower798_devices_json',
    'shower798_current_device_id',
    'local_devices_json',
    'hotwater_history_json',
    'hotwater_session',
    'water_order_snapshot_json',
    'washer_history_json',
    'washer_order_snapshot_json',
  };

  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, value)) {
      throw StateError('旧数据保全写入失败');
    }
  }

  @override
  Future<Map<String, Object>> readLegacyValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return {
      for (final key in legacyKeys)
        if (prefs.containsKey(key)) key: prefs.get(key)!
    };
  }
}

/// 单个 JSON 日志写入成功后才更新内存；所有更新串行，避免多服务登录丢更新。
class LegacyDataMigration {
  LegacyDataMigration(this.store);
  static const backupKey = 'c1_legacy_backup_v1';
  static const journalKey = 'c1_legacy_migration_v1';
  final LegacyMigrationStore store;
  Map<String, dynamic>? _journal;
  Map<String, dynamic> _legacyValues = {};
  Future<void> _tail = Future.value();
  String? failure;
  bool get blocked => _journal == null || failure != null;
  bool get hasLegacy => _journal?['legacy'] == true;
  bool get ready => !blocked;
  bool needsLogin(String service) =>
      blocked || (_journal!['pendingServices'] as List).contains(service);
  bool isPending(String kind, String id) =>
      blocked || recordState(kind, id) == 'pending';
  String? recordState(String kind, String id) =>
      (_journal?['records'] as Map?)?['$kind:$id']?['state'] as String?;
  String? verifiedOwner(String kind, String id) =>
      (_journal?['records'] as Map?)?['$kind:$id']?['owner'] as String?;
  bool get hasPendingRecords =>
      records.values.any((r) => r['state'] == 'pending');
  Map<String, Map<String, dynamic>> get records => {
        for (final e in ((_journal?['records'] as Map?) ?? {}).entries)
          e.key as String: Map<String, dynamic>.from(e.value as Map),
      };

  Future<void> _serial(Future<void> Function() operation) {
    final next = _tail.then((_) => operation());
    _tail = next.catchError((Object _) {});
    return next;
  }

  Future<void> prepare() => _serial(() async {
        try {
          final saved = await store.read(journalKey);
          if (saved != null) {
            final decoded = jsonDecode(saved);
            _validateJournal(decoded);
            // 必须仍有可读取的原始备份，不能仅凭日志放行。
            final backup = await store.read(backupKey);
            if (backup == null) throw const FormatException('备份缺失');
            _legacyValues = _decodeBackup(backup);
            _journal = Map<String, dynamic>.from(decoded as Map);
            failure = null;
            return;
          }
          var backup = await store.read(backupKey);
          if (backup == null) {
            backup = jsonEncode(
                {'version': 1, 'values': await store.readLegacyValues()});
            await store.write(backupKey, backup);
          }
          final values = _decodeBackup(backup);
          _legacyValues = values;
          // 备份保留原始值及类型；解析失败不覆盖原件，不生成完成日志。
          final records = <String, Object>{};
          void add(String kind, String id, String owner,
              {bool simulated = false}) {
            records['$kind:$id'] = {
              'state': simulated || owner == '__simulated__'
                  ? 'simulated'
                  : 'pending',
              'owner': owner,
            };
          }

          if (values.containsKey('hotwater_session')) {
            final s = HotwaterSession.fromJson(
                jsonDecode(values['hotwater_session'] as String)
                    as Map<String, dynamic>);
            add('hotwater', s.id, s.account, simulated: s.simulated);
          }
          if (values.containsKey('water_order_snapshot_json')) {
            final s = WaterOrderCodec.decode(
                values['water_order_snapshot_json'] as String);
            final o = s.currentOrder;
            if (o != null) add('water', o.orderId, o.ownerAccountKey);
          }
          final washerRaw = values['washer_order_snapshot_json'];
          if (values.containsKey('washer_order_snapshot_json')) {
            final s = jsonDecode(washerRaw as String) as Map;
            final history = WasherHistoryCodec.decode(jsonEncode(s['history']));
            for (final h in history) {
              if (h.status != '50' && h.status != 'cancelled') {
                add('washer', h.orderId, h.ownerAccountKey);
              }
            }
            if (s['currentOrder'] != null) {
              final o =
                  WasherHistoryCodec.orderFromMap(s['currentOrder'] as Map);
              add('washer', o.orderId, o.ownerAccountKey);
            }
          } else if (values.containsKey('washer_history_json')) {
            for (final h in WasherHistoryCodec.decode(
                values['washer_history_json'] as String)) {
              if (h.status != '50' && h.status != 'cancelled') {
                add('washer', h.orderId, h.ownerAccountKey);
              }
            }
          }
          // 旧偏好、账号、历史、设备任一存在都不能推断从未使用过模拟。
          final legacy = values.isNotEmpty;
          final journal = <String, dynamic>{
            'version': 1,
            'legacy': legacy,
            'pendingServices':
                legacy ? ['ujing', 'zhuli', 'shower798'] : <String>[],
            'records': records,
          };
          await store.write(journalKey, jsonEncode(journal));
          _journal = journal;
          failure = null;
        } catch (_) {
          failure = '旧数据尚未完成保全，原数据已保留。请重试；请勿清除应用数据。';
        }
      });

  static Map<String, dynamic> _decodeBackup(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map ||
        decoded['version'] != 1 ||
        decoded['values'] is! Map) {
      throw const FormatException('保全备份格式异常');
    }
    return Map<String, dynamic>.from(decoded['values'] as Map);
  }

  /// 展示升级前的只读快照，即使后续刷新覆盖当前历史，旧记录仍可查看。
  List<({String title, String detail})> get preservedHistory {
    final result = <({String title, String detail})>[];
    void read(String key, void Function(String) decode) {
      if (!_legacyValues.containsKey(key)) return;
      try {
        decode(_legacyValues[key] as String);
      } catch (_) {
        result.add((title: '部分旧记录无法展示', detail: '原始数据已保留，未尝试清空或修复'));
      }
    }

    read('hotwater_history_json', (raw) {
      for (final h in HotwaterHistoryCodec.decode(raw)) {
        result.add((
          title: '热水 · ${h.orderId}',
          detail: '${h.time} · ${h.deviceId} · ${h.amount} · ${h.status}'
        ));
      }
    });
    read('water_order_snapshot_json', (raw) {
      final snapshot = WaterOrderCodec.decode(raw);
      final current = snapshot.currentOrder;
      if (current != null) {
        result.add((
          title: '接水 · ${current.orderId}',
          detail:
              '${current.deviceNo} · ${current.payment} · ${current.statusRemark}'
        ));
      }
      for (final h in snapshot.history) {
        result.add((
          title: '接水 · ${h.orderId}',
          detail:
              '${h.completedAt} · ${h.deviceNo} · ${h.payment} · ${h.status}'
        ));
      }
    });
    void washerHistory(String raw) {
      for (final h in WasherHistoryCodec.decode(raw)) {
        result.add((
          title: '洗衣 · ${h.orderId}',
          detail: '${h.deviceNo} · ${h.payPrice} · ${h.statusText}'
        ));
      }
    }

    if (_legacyValues.containsKey('washer_order_snapshot_json')) {
      read('washer_order_snapshot_json', (raw) {
        final snapshot = jsonDecode(raw) as Map;
        washerHistory(jsonEncode(snapshot['history']));
        if (snapshot['currentOrder'] != null) {
          final o =
              WasherHistoryCodec.orderFromMap(snapshot['currentOrder'] as Map);
          result.add((
            title: '洗衣 · ${o.orderId}',
            detail: '${o.deviceNo} · ${o.payPrice} · ${o.statusText}'
          ));
        }
      });
    } else {
      read('washer_history_json', washerHistory);
    }
    read('hotwater_session', (raw) {
      final s =
          HotwaterSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      result.add((
        title: '热水 · ${s.id}',
        detail:
            '${s.deviceId} · 原账号 ${s.account} · ${s.simulated ? "旧模拟记录" : "旧会话"}'
      ));
    });
    return result;
  }

  static void _validateJournal(dynamic value) {
    if (value is! Map ||
        value['version'] != 1 ||
        value['legacy'] is! bool ||
        value['pendingServices'] is! List ||
        value['records'] is! Map ||
        (value['pendingServices'] as List)
            .any((s) => !['ujing', 'zhuli', 'shower798'].contains(s))) {
      throw const FormatException('保全日志格式异常');
    }
    for (final entry in (value['records'] as Map).entries) {
      final r = entry.value;
      if (entry.key is! String ||
          r is! Map ||
          r['owner'] is! String ||
          !['pending', 'simulated', 'verified'].contains(r['state'])) {
        throw const FormatException('保全记录格式异常');
      }
    }
  }

  Future<void> confirmLogin(String service) => _update((journal) {
        (journal['pendingServices'] as List).remove(service);
      });

  Future<void> verifyRecord(String kind, String id, String owner) =>
      _update((journal) {
        final record = (journal['records'] as Map)['$kind:$id'] as Map?;
        if (record == null ||
            record['state'] != 'pending' ||
            owner.isEmpty ||
            (record['owner'] != '' && record['owner'] != owner)) {
          throw StateError('旧记录归属不匹配');
        }
        record['state'] = 'verified';
        record['owner'] = owner;
      });

  Future<void> _update(void Function(Map<String, dynamic>) change) =>
      _serial(() async {
        if (blocked) throw StateError('旧数据尚未完成保全');
        final next = jsonDecode(jsonEncode(_journal)) as Map<String, dynamic>;
        change(next);
        try {
          await store.write(journalKey, jsonEncode(next));
          _journal = next;
        } catch (_) {
          failure = '旧数据核对进度保存失败，原记录已保留，请重试。';
          rethrow;
        }
      });
}
