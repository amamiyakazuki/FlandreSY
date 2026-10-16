import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/method_channel_shared_preferences.dart';
import 'package:flandresy/src/data/shared_prefs_local_device_repository.dart';
import 'package:flandresy/src/data/local_device_repository.dart';
import 'package:flandresy/src/data/account_session_repository.dart';
import 'package:flandresy/src/data/secure_session_repository.dart';
import 'package:flandresy/src/data/settings_repository.dart';
import 'package:flandresy/src/data/legacy_data_migration.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'support/fake_shower798_adapter.dart';
import 'support/test_runtime.dart';
import 'support/memory_migration_store.dart';
import 'c2_devices_test.dart'
    show ControlledDevices, QueryUjing, program, washer, hidden, tick;

class InstantShower extends FakeShower798Adapter {
  int stops = 0;
  @override
  Future<void> startShower(String id) async {}
  @override
  Future<void> stopShower(String id) async {
    stops++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'SharedPreferences false and exception restore disk-backed cache; retry works',
      () async {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance =
        MethodChannelSharedPreferencesStore();
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final disk = <String, Object>{
      'flutter.local_devices_json': LocalDeviceCodec.encode([washer])
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
    final repo = SharedPrefsLocalDeviceRepository();
    for (final failure in ['false', 'throw']) {
      mode = failure;
      await expectLater(repo.saveDevices([hidden]), throwsA(anything));
      expect((await repo.loadDevices())!.single.id, washer.id);
      expect(
          (await SharedPreferences.getInstance())
              .getString('local_devices_json'),
          LocalDeviceCodec.encode([washer]));
    }
    mode = 'ok';
    await repo.saveDevices([hidden]);
    expect((await repo.loadDevices())!.single.id, hidden.id);
  });
  for (final fail in [false, true]) {
    test(
        'hotwater stop shares queue with edit and preserves physical result, fail=$fail',
        () async {
      final repo = ControlledDevices([washer, hidden])..failAt = fail ? 2 : 0;
      final api = InstantShower();
      final runtime = TestRuntime(
          devices: repo,
          shower798: api,
          settings: InMemorySettingsRepository(
              initial: BathSystemPreference.shower798),
          secure: InMemorySecureSessionRepository(shower798Token: 'test'),
          sessions: InMemoryAccountSessionRepository(
              shower798: Shower798Persisted(
                  account: const Shower798AccountUi(
                      mobile: 'account', uid: 'u', eid: 'e'),
                  devices: [Shower798DeviceUi(id: hidden.id, name: '旧热水')],
                  currentDeviceId: hidden.id)));
      addTearDown(runtime.dispose);
      await runtime.ready;
      await runtime.startShower798();
      expect(runtime.state.hotwaterRunning, isTrue);
      final gate = repo.gate = Completer<void>();
      final rename = runtime.renameLocalDevice(washer.id, '新名');
      await tick();
      final stop = runtime.stopShower798();
      await tick();
      expect(repo.calls, 1);
      gate.complete();
      await rename;
      await stop;
      expect(api.stops, 1);
      expect(runtime.state.hotwaterStop.state, RuntimeTaskState.success);
      expect(runtime.state.hotwaterRunning, isFalse);
      expect(runtime.state.localDevices.first.customName, '新名');
      if (fail) {
        expect(runtime.state.devicesNotice.message, contains('关水结果已确认'));
      } else {
        expect(runtime.state.localDevices.last.lastStatus, '停止请求已确认');
        expect((await repo.loadDevices())!.first.customName, '新名');
      }
    });
  }
  test('C1 relogin gate blocks network without removing legacy devices',
      () async {
    final api = QueryUjing((_) async => program);
    final migration = LegacyDataMigration(
        MemoryMigrationStore({'use_simulated_backend': false}));
    final runtime = TestRuntime(
        devices: ControlledDevices([washer]), ujing: api, migration: migration);
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.refreshLocalDevices();
    expect(api.calls, 0);
    expect(runtime.state.devicesRefresh.state, RuntimeTaskState.loginRequired);
    expect(runtime.state.localDevices.length, 1);
  });
}
