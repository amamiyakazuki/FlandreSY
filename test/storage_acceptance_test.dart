import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flandresy/src/data/app_bootstrap.dart';
import 'package:flandresy/src/data/shared_prefs_account_session_repository.dart';
import 'package:flandresy/src/data/shared_prefs_history_repository.dart';
import 'package:flandresy/src/data/shared_prefs_local_device_repository.dart';
import 'package:flandresy/src/data/shared_prefs_settings_repository.dart';
import 'package:flandresy/src/data/shared_prefs_water_order_repository.dart';
import 'package:flandresy/src/data/shared_prefs_washer_history_repository.dart';
import 'package:flandresy/src/runtime/fake_shui_runtime.dart';

void main() {
  test(
      'corrupt order domain preserves raw data and blocks creates while healthy account restores',
      () async {
    SharedPreferences.setMockInitialValues({
      'water_order_snapshot_json': '{broken-order',
      'local_devices_json': '{broken-devices',
      'ujing_mobile': '13800000001',
      'ujing_user_id': 'user-a',
      'bath_system_preference': 'shower798',
      'permission_intro_seen': true,
    });
    final snapshot = await _load();
    expect(snapshot.ujing?.mobile, '13800000001');
    expect(snapshot.bathSystem, BathSystemPreference.shower798);
    expect(snapshot.permissionIntroSeen, isTrue);
    expect(snapshot.recoveryWarnings.length, 2);
    expect(snapshot.ujingOrderStorageBlocked, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('water_order_snapshot_json'), '{broken-order');
    expect(prefs.getString('local_devices_json'), '{broken-devices');
    expect(prefs.getString('local_devices_json_recovery_backup'),
        '{broken-devices');
    final runtime = FakeShuiRuntime(
        initial: snapshot,
        water: SharedPrefsWaterOrderRepository(),
        washerHistory: SharedPrefsWasherHistoryRepository());
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.scanDrinkingWaterAndCreateOrder('device-b');
    expect(runtime.state.currentWaterOrder, isNull);
    expect(runtime.ujingOrderStorageBlocked, isTrue);
    expect(prefs.getString('water_order_snapshot_json'), '{broken-order');
    expect(runtime.state.waterOrder.isBusy, isFalse);
  });

  test('backup survives later healthy save and later corrupt reads', () async {
    SharedPreferences.setMockInitialValues(
        {'local_devices_json': '{original-bad'});
    final repo = SharedPrefsLocalDeviceRepository();
    await expectLater(repo.loadDevices(), throwsA(isA<FormatException>()));
    final prefs = await SharedPreferences.getInstance();
    await repo.saveDevices([]);
    expect(await repo.loadDevices(), isEmpty);
    expect(
        prefs.getString('local_devices_json_recovery_backup'), '{original-bad');
    await prefs.setString('local_devices_json', '{new-bad');
    await expectLater(repo.loadDevices(), throwsA(isA<FormatException>()));
    expect(prefs.getString('local_devices_json'), '{new-bad');
    expect(
        prefs.getString('local_devices_json_recovery_backup'), '{original-bad');
  });

  test('broken hotwater session cannot erase healthy Ujing order snapshot',
      () async {
    SharedPreferences.setMockInitialValues({
      'hotwater_session': '{}',
      'water_order_snapshot_json':
          '{"currentOrder":{"orderId":"old-order","orderStatus":"0"},"history":[]}',
    });
    final snapshot = await _load();
    expect(snapshot.hotwaterSession, isNull);
    expect(snapshot.currentWaterOrder?.orderId, 'old-order');
    expect(snapshot.ujingOrderStorageBlocked, isFalse);
    expect(snapshot.recoveryWarnings.single, contains('热水会话'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('hotwater_session'), '{}');
    expect(prefs.getString('hotwater_session_recovery_backup'), '{}');
  });

  test(
      'corrupt washer aggregate blocks mutation and keeps original legacy history',
      () async {
    SharedPreferences.setMockInitialValues({
      'washer_order_snapshot_json': '{broken-snapshot',
      'washer_history_json': '[{"orderId":"retained","status":"40"}]',
      'hotwater_history_json': '[]',
    });
    final snapshot = await _load();
    expect(snapshot.ujingOrderStorageBlocked, isTrue);
    expect(snapshot.hotwaterHistory, isEmpty);
    expect(snapshot.recoveryWarnings.length, 2);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('washer_order_snapshot_json'), '{broken-snapshot');
    expect(prefs.getString('washer_history_json'), contains('retained'));
  });
}

Future<PersistedSnapshot> _load() => AppBootstrap.load(
    SharedPrefsSettingsRepository(),
    SharedPrefsAccountSessionRepository(),
    SharedPrefsLocalDeviceRepository(),
    SharedPrefsHistoryRepository(),
    SharedPrefsWaterOrderRepository(),
    SharedPrefsWasherHistoryRepository());
