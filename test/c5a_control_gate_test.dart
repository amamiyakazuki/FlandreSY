import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/adapters/hotwater_adapter.dart';
import 'package:flandresy/src/data/adapters/ble_transport.dart';
import 'package:flandresy/src/data/adapters/flutter_blue_plus_ble_transport.dart';
import 'package:flandresy/src/data/adapters/real_zhuli_adapter.dart';
import 'package:flandresy/src/data/adapters/zhuli_transport.dart';
import 'package:flandresy/src/data/app_bootstrap.dart';
import 'package:flandresy/src/data/account_session_repository.dart';
import 'package:flandresy/src/data/settings_repository.dart';
import 'package:flandresy/src/data/permission_service.dart';
import 'package:flandresy/src/runtime/hotwater_state.dart';
import 'package:flandresy/src/runtime/live_clock.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'support/fake_hotwater_adapter.dart';
import 'support/fake_shower798_adapter.dart';
import 'support/test_runtime.dart';
import 'c5a_permissions_test.dart' show TestPermissionBackend;

class UnsupportedHotwater extends FakeHotwaterAdapter
    implements HotwaterControlReadiness {
  @override
  String? get controlUnavailableReason => iosZhuliUnavailable;
  int starts = 0, stops = 0;
  @override
  Future<HotwaterActionResult> startHotwater(String id,
      {HotwaterStartProgressCallback? onProgress}) async {
    starts++;
    throw StateError('must not start');
  }

  @override
  Future<HotwaterActionResult> stopHotwater(String id, {String? isn}) async {
    stops++;
    throw StateError('must not stop');
  }
}

class CountingHttp implements ZhuliTransport {
  int calls = 0;
  @override
  Future<Map<String, dynamic>> getObject(ZhuliRequest request) async {
    calls++;
    return {};
  }

  @override
  Future<String> getString(ZhuliRequest request) async {
    calls++;
    return '';
  }

  @override
  Future<List<dynamic>> getArray(ZhuliRequest request) async {
    calls++;
    return [];
  }
}

class RejectedBle extends SkeletonBleTransport implements BleControlReadiness {
  @override
  String? get controlUnavailableReason => null;
  @override
  Future<void> prepareControl() async => throw const HotwaterException('权限未授予');
}

class InstantShower extends FakeShower798Adapter {
  int starts = 0;
  @override
  Future<void> startShower(String id) async {
    starts++;
  }
}

void main() {
  for (final phase in [
    HotwaterSessionPhase.active,
    HotwaterSessionPhase.uncertain,
    HotwaterSessionPhase.preparing
  ]) {
    test(
        'iOS $phase expired session remains through restore, start/stop and verification',
        () async {
      final session = HotwaterSession(
          id: 'old',
          account: 'A',
          system: BathSystemPreference.zhuli,
          simulated: false,
          deviceId: 'device',
          startedAtMillis: 1,
          baselineOrderIds: const [],
          phase: phase);
      final settings = InMemorySettingsRepository();
      await settings.saveHotwaterSession(session);
      final api = UnsupportedHotwater();
      final runtime = TestRuntime(
          hotwater: api,
          settings: settings,
          clock: const FixedLiveClock(999999999),
          initial: PersistedSnapshot(
              bathSystem: BathSystemPreference.zhuli,
              zhuli: const ZhuliSession(phone: 'A', deviceCode: 'device'),
              hotwaterSession: session));
      addTearDown(runtime.dispose);
      await runtime.ready;
      expect(runtime.state.hotwater.session, same(session));
      expect(runtime.state.hotwaterStart.message, contains('旧会话已保留'));
      await runtime.startHotwater();
      await runtime.stopActiveHotwater();
      expect(runtime.state.hotwaterStart.state, RuntimeTaskState.unavailable);
      expect(runtime.state.hotwaterStop.state, RuntimeTaskState.unavailable);
      expect(await runtime.verifyLegacyHotwater(), isFalse);
      expect(await settings.loadHotwaterSession(), same(session));
      expect(api.starts + api.stops, 0);
      runtime.setPollingPaused(true);
      runtime.setPollingPaused(false);
      await Future<void>.delayed(Duration.zero);
      expect(runtime.state.hotwater.session, same(session));
    });
  }
  test('iOS rejected new control creates no local session', () async {
    final api = UnsupportedHotwater();
    final settings = InMemorySettingsRepository();
    final runtime = TestRuntime(hotwater: api, settings: settings);
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.startHotwater();
    expect(await settings.loadHotwaterSession(), isNull);
    expect(runtime.state.hotwaterStart.message, iosZhuliUnavailable);
    expect(api.starts, 0);
  });
  for (final start in [true, false]) {
    test('production iOS adapter blocks before HTTP or radio: start=$start',
        () async {
      final backend = TestPermissionBackend(target: TargetPlatform.iOS);
      final http = CountingHttp();
      final ble = FlutterBluePlusBleTransport(
          permissions: ShuiPermissionService(backend: backend));
      final api = RealZhuliAdapter(transport: http, ble: ble);
      expect(api.controlUnavailableReason, iosZhuliUnavailable);
      await expectLater(
          start
              ? api.startHotwater('device')
              : api.stopHotwater('device', isn: 'private'),
          throwsA(isA<HotwaterException>()
              .having((e) => e.message, 'message', iosZhuliUnavailable)));
      expect(http.calls, 0);
      expect(backend.requests, isEmpty);
      expect(backend.checked, isEmpty);
    });
    test('Android permission rejection precedes HTTP control: start=$start',
        () async {
      final http = CountingHttp();
      final api = RealZhuliAdapter(transport: http, ble: RejectedBle());
      await expectLater(
          start
              ? api.startHotwater('device')
              : api.stopHotwater('device', isn: 'private'),
          throwsA(isA<HotwaterException>()
              .having((e) => e.message, 'message', '权限未授予')));
      expect(http.calls, 0);
    });
  }
  test('direct iOS transport use is gated too', () async {
    final backend = TestPermissionBackend(target: TargetPlatform.iOS);
    final ble = FlutterBluePlusBleTransport(
        permissions: ShuiPermissionService(backend: backend));
    await expectLater(
        ble.scanAndConnect(bleName: 'same-name', bleMac: 'AA:BB:CC:DD:EE:FF'),
        throwsA(isA<HotwaterException>()));
    expect(backend.requests, isEmpty);
  });
  test('iOS Zhuli history remains available independently of BLE', () async {
    final http = CountingHttp();
    final api = RealZhuliAdapter(
        transport: http,
        ble: FlutterBluePlusBleTransport(
            permissions: ShuiPermissionService(
                backend: TestPermissionBackend(target: TargetPlatform.iOS))),
        session: const ZhuliSessionData(
            platformToken: 'token',
            userId: 'u',
            identityCode: '',
            serverAddr: 'https://example.invalid',
            serverAppId: '',
            serverId: '',
            secretKey: 'key'));
    expect(await api.loadHistory(), isEmpty);
    expect(http.calls, greaterThan(0));
  });
  test('798 remains usable when Zhuli control is unavailable', () async {
    final shower = InstantShower();
    final runtime = TestRuntime(
        hotwater: UnsupportedHotwater(),
        shower798: shower,
        initial: const PersistedSnapshot(
            bathSystem: BathSystemPreference.shower798,
            shower798: Shower798Persisted(
                account: Shower798AccountUi(mobile: 'A', uid: 'u', eid: 'e'),
                currentDeviceId: 'device')));
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.startShower798();
    expect(shower.starts, 1);
    expect(runtime.state.hotwaterRunning, isTrue);
  });
}
