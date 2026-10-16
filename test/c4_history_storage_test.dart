import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/method_channel_shared_preferences.dart';
import 'package:flandresy/src/data/history_repository.dart';
import 'package:flandresy/src/data/shared_prefs_history_repository.dart';
import 'package:flandresy/src/data/legacy_data_migration.dart';
import 'support/memory_migration_store.dart';
import 'support/test_runtime.dart';
import 'c4_history_ownership_test.dart' show old, record, HistoryAdapter, login;

void main() {
  test('legacy codec has no guessed owner; mixed archive roundtrips losslessly',
      () {
    final legacyMap = HotwaterHistoryCodec.toMap(old)..remove('ownerAccount');
    final legacy = HotwaterHistoryCodec.decode(jsonEncode([legacyMap])).single;
    expect(legacy.ownerAccount, '');
    final all = [
      legacy,
      record('same-id').ownedBy('A'),
      record('same-id').ownedBy('B')
    ];
    final restored =
        HotwaterHistoryCodec.decode(HotwaterHistoryCodec.encode(all));
    expect(restored.map(HotwaterHistoryCodec.toMap),
        all.map(HotwaterHistoryCodec.toMap));
    expect(restored.map((h) => h.ownerAccount), ['', 'A', 'B']);
  });

  for (final owner in [42, {}, []]) {
    test(
        'malformed owner is recoverable, never coerced into a different identity: $owner',
        () async {
      final raw = jsonEncode(
          [HotwaterHistoryCodec.toMap(old)..['ownerAccount'] = owner]);
      SharedPreferences.setMockInitialValues({'hotwater_history_json': raw});
      await expectLater(
          SharedPrefsHistoryRepository().loadHistory(), throwsFormatException);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('hotwater_history_json'), raw);
      expect(prefs.getString('hotwater_history_json_recovery_backup'), raw);
    });
  }

  test('cold restart retains owners, old archive, and account filtering',
      () async {
    SharedPreferences.setMockInitialValues({
      'hotwater_history_json': HotwaterHistoryCodec.encode([old])
    });
    final api = HistoryAdapter()..loader = () async => [record('a')];
    final r =
        TestRuntime(history: SharedPrefsHistoryRepository(), hotwater: api);
    await r.ready;
    await login(r, 'A');
    await r.loadHotwaterHistory();
    r.dispose();
    final restarted = TestRuntime(
        history: SharedPrefsHistoryRepository(), hotwater: HistoryAdapter());
    addTearDown(restarted.dispose);
    await restarted.ready;
    expect(restarted.state.currentHotwaterHistory, isEmpty);
    await login(restarted, 'B');
    expect(restarted.state.currentHotwaterHistory, isEmpty);
    await login(restarted, 'A');
    expect(restarted.state.currentHotwaterHistory.single.orderId, 'a');
    expect(restarted.state.unassignedHotwaterHistory.single.orderId, 'old');
  });

  test('false and throwing storage writes restore disk cache and permit retry',
      () async {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance =
        MethodChannelSharedPreferencesStore();
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final disk = <String, Object>{
      'flutter.hotwater_history_json': HotwaterHistoryCodec.encode([old])
    };
    var mode = 'false';
    const channel = MethodChannel('plugins.flutter.io/shared_preferences');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAll') return Map.of(disk);
      if (call.method == 'setString') {
        if (mode == 'false') return false;
        if (mode == 'throw') throw PlatformException(code: 'disk');
        final args = call.arguments as Map;
        disk[args['key'] as String] = args['value'] as Object;
        return true;
      }
      throw StateError('unexpected ${call.method}');
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final repo = SharedPrefsHistoryRepository();
    for (final failure in ['false', 'throw']) {
      mode = failure;
      await expectLater(
          repo.saveHistory([record('a').ownedBy('A')]), throwsA(anything));
      expect((await repo.loadHistory())!.single.orderId, 'old');
      expect(
          (await SharedPreferences.getInstance())
              .getString('hotwater_history_json'),
          HotwaterHistoryCodec.encode([old]));
    }
    mode = 'ok';
    await repo.saveHistory([old, record('a').ownedBy('A')]);
    expect((await repo.loadHistory())!.last.ownerAccount, 'A');
  });

  for (final blocked in [false, true]) {
    test(
        'C1 pending login / failed preservation forbids query, blocked=$blocked',
        () async {
      final store = MemoryMigrationStore({
        'zhuli_phone': 'A',
        'hotwater_history_json': HotwaterHistoryCodec.encode([old])
      });
      if (blocked) store.failKey = LegacyDataMigration.backupKey;
      final api = HistoryAdapter();
      final r = TestRuntime(
          migration: LegacyDataMigration(store),
          hotwater: api,
          history: InMemoryHistoryRepository(history: [old]));
      addTearDown(r.dispose);
      await r.loadHotwaterHistory();
      expect(api.calls, 0);
      expect(r.state.unassignedHotwaterHistory.single.orderId, 'old');
      expect(r.state.hotwater.historyStatus.state,
          blocked ? RuntimeTaskState.failure : RuntimeTaskState.loginRequired);
    });
  }
}
