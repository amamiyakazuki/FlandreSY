import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flandresy/src/data/account_session_repository.dart';
import 'package:flandresy/src/data/shared_prefs_account_session_repository.dart';
import 'package:flandresy/src/data/secure_session_repository.dart';
import 'package:flandresy/src/data/adapters/fake_hotwater_adapter.dart';
import 'package:flandresy/src/data/adapters/fake_ujing_adapter.dart';
import 'package:flandresy/src/data/adapters/fake_shower798_adapter.dart';
import 'package:flandresy/src/data/adapters/hotwater_adapter.dart';
import 'package:flandresy/src/data/adapters/ujing_adapter.dart';
import 'package:flandresy/src/data/adapters/shower798_adapter.dart';
import 'package:flandresy/src/runtime/fake_shui_runtime.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'package:flandresy/src/runtime/hotwater_state.dart';

const _zhuli = ZhuliSession(phone: 'a', deviceCode: 'device');
const _ujing = UjingAccountUi(mobile: 'a', userId: 'u', serviceSubjectId: 's');
const _shower = Shower798Persisted(
    account: Shower798AccountUi(mobile: 'a', uid: 'u', eid: 'e'),
    devices: [Shower798DeviceUi(id: 'd', name: 'device')],
    currentDeviceId: 'd');

class _Probe {
  int calls = 0;
  Object? error;
  Completer<void>? gate;
  Future<void> run() async {
    calls++;
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
  }
}

class _Hot extends FakeHotwaterAdapter {
  _Hot(this.probe);
  final _Probe probe;
  @override
  Future<void> checkAccountValidity() => probe.run();
}

class _Water extends FakeUjingAdapter {
  _Water(this.probe);
  final _Probe probe;
  @override
  Future<void> checkAccountValidity() => probe.run();
}

class _Shower extends FakeShower798Adapter {
  _Shower(this.probe);
  final _Probe probe;
  @override
  Future<void> checkAccountValidity() => probe.run();
}

Future<FakeShuiRuntime> _runtime(_Probe probe,
    {AccountSessionRepository? sessions,
    SecureSessionRepository? secure,
    IHotwaterAdapter? hotwater,
    IShower798Adapter? shower}) async {
  final runtime = FakeShuiRuntime(
      hotwater: hotwater ?? _Hot(probe),
      ujing: _Water(probe),
      shower798: shower ?? _Shower(probe),
      secure: secure,
      sessions: sessions ??
          InMemoryAccountSessionRepository(
              zhuli: _zhuli, ujing: _ujing, shower798: _shower));
  addTearDown(runtime.dispose);
  await runtime.ready;
  return runtime;
}

bool _logged(FakeShuiRuntime runtime, AccountKind kind) => switch (kind) {
      AccountKind.zhuli => runtime.state.zhuli.isLoggedIn,
      AccountKind.ujing => runtime.state.ujingAccount != null,
      AccountKind.shower798 => runtime.state.shower798Account != null,
    };

void main() {
  test('late probe 401 cannot discard a hotwater command sent after the probe',
      () async {
    final probe = _Probe()
      ..gate = Completer<void>()
      ..error = const HotwaterException('expired', authInvalid: true);
    final hot = _GateHot(probe);
    final secure = InMemorySecureSessionRepository();
    final runtime = await _runtime(probe, hotwater: hot, secure: secure);
    final checking = runtime.checkAccountStatus(AccountKind.zhuli);
    await Future<void>.delayed(Duration.zero);
    final epoch = runtime.hotwaterAuthEpoch;
    final start = runtime.startHotwater();
    await hot.started.future;
    probe.gate!.complete();
    await checking;
    expect(runtime.hotwaterAuthEpoch, epoch);
    expect(runtime.state.zhuli.isLoggedIn, isTrue);
    expect(runtime.state.account.availability[AccountKind.zhuli]?.state,
        RuntimeTaskState.unavailable);
    hot.release.complete();
    await start;
    expect(runtime.state.hotwater.session?.phase, HotwaterSessionPhase.active);
    expect(await secure.loadHotwaterIsn(runtime.state.hotwater.session!.id),
        'fake-isn');
  });

  test(
      'logout waits for actual 798 remote add and keeps the successful device result',
      () async {
    final probe = _Probe();
    final shower = _GateShower(probe);
    final sessions = InMemoryAccountSessionRepository(shower798: _shower);
    final runtime = await _runtime(probe, shower: shower, sessions: sessions);
    final adding = runtime.addShower798Device('new-device');
    await shower.started.future;
    await runtime.logoutAccount(AccountKind.shower798);
    expect(runtime.state.shower798Account, isNotNull);
    shower.release.complete();
    await adding;
    expect((await sessions.loadShower798())!.currentDeviceId, 'new-device');
    await runtime.logoutAccount(AccountKind.shower798);
    expect(runtime.state.shower798Account, isNull);
    expect((await sessions.loadShower798())!.devices.single.id, 'new-device');
  });
  for (final kind in AccountKind.values) {
    test('$kind probes coalesce, preserve login status and distinguish network',
        () async {
      final probe = _Probe()..gate = Completer<void>();
      final runtime = await _runtime(probe);
      final original = runtime.state.account;
      final a = runtime.checkAccountStatus(kind);
      final b = runtime.checkAccountStatus(kind);
      await Future<void>.delayed(Duration.zero);
      expect(probe.calls, 1);
      expect(runtime.state.hotwaterLogin, original.hotwaterLogin);
      expect(runtime.state.washerLogin, original.washerLogin);
      expect(runtime.state.shower798Login, original.shower798Login);
      probe.gate!.complete();
      await Future.wait([a, b]);
      expect(runtime.state.account.availability[kind]?.state,
          RuntimeTaskState.success);
      probe.error = TimeoutException('offline');
      await runtime.checkAccountStatus(kind);
      expect(_logged(runtime, kind), isTrue);
      expect(runtime.state.account.availability[kind]?.state,
          RuntimeTaskState.unavailable);
    });

    test('$kind explicit auth refusal clears only that login', () async {
      final probe = _Probe()
        ..error = switch (kind) {
          AccountKind.zhuli =>
            const HotwaterException('expired', authInvalid: true),
          AccountKind.ujing =>
            const UjingException('expired', authInvalid: true),
          AccountKind.shower798 =>
            const Shower798Exception('expired', authInvalid: true),
        };
      final runtime = await _runtime(probe);
      await runtime.checkAccountStatus(kind);
      for (final other in AccountKind.values) {
        expect(_logged(runtime, other), other != kind);
      }
      expect(runtime.state.account.availability[kind]?.state,
          RuntimeTaskState.loginRequired);
    });

    test(
        '$kind local logout works despite stale loading and late probe cannot relogin',
        () async {
      final probe = _Probe()..gate = Completer<void>();
      final runtime = await _runtime(probe);
      final checking = runtime.checkAccountStatus(kind);
      await Future<void>.delayed(Duration.zero);
      runtime.emit(runtime.state.copyWith(
          hotwaterLogin:
              const RuntimeActionStatus(state: RuntimeTaskState.loading),
          washerLogin:
              const RuntimeActionStatus(state: RuntimeTaskState.loading),
          shower798Login:
              const RuntimeActionStatus(state: RuntimeTaskState.loading)));
      await runtime.logoutAccount(kind);
      expect(_logged(runtime, kind), isFalse);
      expect(
          runtime.state.account.availability[kind]?.message, contains('已退出'));
      probe.gate!.complete();
      await checking;
      expect(_logged(runtime, kind), isFalse);
      expect(
          runtime.state.account.availability[kind]?.message, contains('已退出'));
      final calls = probe.calls;
      await runtime.checkAccountStatus(kind);
      expect(probe.calls, calls);
    });

    test('$kind late failed check cannot clear a newer login generation',
        () async {
      final probe = _Probe()
        ..gate = Completer<void>()
        ..error = switch (kind) {
          AccountKind.zhuli =>
            const HotwaterException('expired', authInvalid: true),
          AccountKind.ujing =>
            const UjingException('expired', authInvalid: true),
          AccountKind.shower798 =>
            const Shower798Exception('expired', authInvalid: true),
        };
      final runtime = await _runtime(probe);
      final checking = runtime.checkAccountStatus(kind);
      await Future<void>.delayed(Duration.zero);
      if (kind == AccountKind.ujing) {
        runtime.beginUjingLoginEpoch();
      } else {
        runtime.hotwaterAuthEpoch++;
      }
      probe.gate!.complete();
      await checking;
      expect(_logged(runtime, kind), isTrue);
      expect(runtime.state.account.availability[kind]?.isBusy, isFalse);
    });
  }

  test(
      'logout preserves hotwater session and stop isn, fails visibly then retries local cleanup',
      () async {
    final secure = _FailClear()..fail = true;
    await secure.saveHotwaterIsn('active', 'stop-proof');
    final runtime = await _runtime(_Probe(), secure: secure);
    const session = HotwaterSession(
        id: 'active',
        account: 'a',
        system: BathSystemPreference.zhuli,
        simulated: true,
        deviceId: 'device',
        startedAtMillis: 1,
        baselineOrderIds: [],
        phase: HotwaterSessionPhase.active);
    runtime.emit(runtime.state.copyWith(
        hotwater:
            runtime.state.hotwater.copyWith(session: session, running: true)));
    await runtime.logoutAccount(AccountKind.zhuli);
    expect(runtime.state.account.availability[AccountKind.zhuli]?.state,
        RuntimeTaskState.failure);
    expect(runtime.state.hotwater.session, session);
    expect(runtime.state.hotwaterRunning, isTrue);
    expect(runtime.state.zhuli.deviceCode, 'device');
    expect(await secure.loadHotwaterIsn('active'), 'stop-proof');
    secure.fail = false;
    await runtime.logoutAccount(AccountKind.zhuli);
    expect(runtime.state.account.availability[AccountKind.zhuli]?.state,
        RuntimeTaskState.success);
  });

  test(
      'real preferences 798 logout preserves device configuration after restart',
      () async {
    SharedPreferences.setMockInitialValues({});
    final sessions = SharedPrefsAccountSessionRepository();
    await sessions.saveShower798(_shower);
    final runtime = await _runtime(_Probe(), sessions: sessions);
    await runtime.logoutAccount(AccountKind.shower798);
    final restored = await _runtime(_Probe(), sessions: sessions);
    expect(restored.state.shower798Account, isNull);
    expect(restored.state.shower798Devices.single.id, 'd');
    expect(restored.state.currentShower798DeviceId, 'd');
    expect(await sessions.loadUjing(), isNull);
  });

  test(
      'actual mutation guard does not clear account or order while command is in flight',
      () async {
    final runtime = await _runtime(_Probe());
    runtime.ujingMutationCount++;
    await runtime.logoutAccount(AccountKind.ujing);
    expect(runtime.state.ujingAccount, isNotNull);
    expect(runtime.state.account.availability[AccountKind.ujing]?.state,
        RuntimeTaskState.unavailable);
    runtime.ujingMutationCount--;
    await runtime.logoutAccount(AccountKind.ujing);
    expect(runtime.state.ujingAccount, isNull);
  });
}

class _GateHot extends _Hot {
  _GateHot(super.probe);
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<HotwaterActionResult> startHotwater(String deviceId,
      {HotwaterStartProgressCallback? onProgress}) async {
    started.complete();
    await release.future;
    return super.startHotwater(deviceId, onProgress: onProgress);
  }
}

class _GateShower extends _Shower {
  _GateShower(super.probe);
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> addDevice(String deviceId) async {
    started.complete();
    await release.future;
  }

  @override
  Future<List<Shower798DeviceUi>> loadDevices() async => const [
        Shower798DeviceUi(id: 'new-device', name: 'added'),
      ];
}

class _FailClear extends InMemorySecureSessionRepository {
  bool fail = false;
  @override
  Future<void> clearZhuliSession() async {
    if (fail) throw StateError('storage');
    await super.clearZhuliSession();
  }
}
