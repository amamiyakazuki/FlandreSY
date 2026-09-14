import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flandresy/src/data/adapters/ble_transport.dart';
import 'package:flandresy/src/data/adapters/hotwater_adapter.dart';
import 'package:flandresy/src/data/adapters/real_zhuli_adapter.dart';
import 'package:flandresy/src/data/adapters/zhuli_transport.dart';
import 'package:flandresy/src/data/app_bootstrap.dart';
import 'package:flandresy/src/data/secure_session_repository.dart';
import 'package:flandresy/src/data/settings_repository.dart';
import 'package:flandresy/src/data/shared_prefs_settings_repository.dart';
import 'package:flandresy/src/hotwater/hotwater_detail_screen.dart';
import 'package:flandresy/src/runtime/fake_shui_runtime.dart';
import 'package:flandresy/src/runtime/hotwater_state.dart';
import 'package:flandresy/src/runtime/live_clock.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'package:flandresy/src/runtime/models/hotwater_history.dart';
import 'package:flandresy/src/shell/shui_shell.dart';

void main() {
  group('hotwater session migration', () {
    test('legacy version 1 becomes uncertain and malformed data is rejected',
        () {
      final legacy = HotwaterSession.fromJson(_sessionJson(version: 1));

      expect(legacy.phase, HotwaterSessionPhase.uncertain);
      expect(legacy.orderId, isEmpty);
      expect(legacy.account, '13800000000');
      expect(legacy.deviceId, 'device-1');

      expect(
        () => HotwaterSession.fromJson(
          _sessionJson(version: 2)..['phase'] = 'not-a-phase',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('corrupt shared session is removed without blocking boot', () async {
      SharedPreferences.setMockInitialValues({
        'hotwater_session': '{"version":99}',
      });

      final settings = SharedPrefsSettingsRepository();

      expect(await settings.loadHotwaterSession(), isNull);
      expect(
        (await SharedPreferences.getInstance()).getString('hotwater_session'),
        isNull,
      );
    });
  });

  group('hotwater startup recovery', () {
    test('pre-dispatch scan failure clears state and allows retry', () async {
      final adapter = _TestHotwaterAdapter(failBeforeDispatchOnce: true);
      final settings = InMemorySettingsRepository(
        initial: BathSystemPreference.zhuli,
      );
      final secure = InMemorySecureSessionRepository();
      final runtime = _runtime(
        adapter: adapter,
        settings: settings,
        secure: secure,
      );
      addTearDown(runtime.dispose);

      await runtime.ready;
      await runtime.startHotwater();

      expect(adapter.startCalls, 1);
      expect(await settings.loadHotwaterSession(), isNull);
      expect(await secure.loadHotwaterIsn('any-session'), isNull);
      expect(runtime.state.hotwater.session, isNull);
      expect(runtime.state.hotwaterStart.state, RuntimeTaskState.failure);
      expect(runtime.state.hotwaterStart.message, '未扫描到设备');

      final historyCallsAfterFailure = adapter.loadHistoryCalls;
      await runtime.pollHotwaterStatusOnce();
      expect(adapter.loadHistoryCalls, historyCallsAfterFailure);

      await runtime.startHotwater();
      expect(adapter.startCalls, 2);
      expect(
        runtime.state.hotwater.session?.phase,
        HotwaterSessionPhase.active,
      );
    });

    test('lost response after dispatch keeps uncertain session and isn',
        () async {
      final adapter = _TestHotwaterAdapter(loseResponseAfterDispatchOnce: true);
      final settings = InMemorySettingsRepository(
        initial: BathSystemPreference.zhuli,
      );
      final secure = InMemorySecureSessionRepository();
      final runtime = _runtime(
        adapter: adapter,
        settings: settings,
        secure: secure,
      );
      addTearDown(runtime.dispose);

      await runtime.ready;
      await runtime.startHotwater();

      final persisted = await settings.loadHotwaterSession();
      expect(persisted, isNotNull);
      expect(persisted!.phase, HotwaterSessionPhase.uncertain);
      expect(persisted.orderId, 'order-1');
      expect(await secure.loadHotwaterIsn(persisted.id), 'isn-1');
      expect(runtime.state.hotwater.session?.phase,
          HotwaterSessionPhase.uncertain);
      expect(runtime.state.hotwaterStart.state, RuntimeTaskState.unavailable);
      expect(runtime.state.hotwaterStart.message, contains('待确认'));
      expect(adapter.stopCalls, 0);

      final callsBeforePoll = adapter.loadHistoryCalls;
      await runtime.pollHotwaterStatusOnce();
      expect(adapter.loadHistoryCalls, callsBeforePoll + 1);
      expect(runtime.state.hotwater.session, isNotNull);
      expect(runtime.state.hotwaterStart.message, '热水状态待确认');
      expect(adapter.stopCalls, 0);
    });

    test('legacy missing-isn session can be locally cleared without stop',
        () async {
      final adapter = _TestHotwaterAdapter();
      final legacy = HotwaterSession.fromJson(_sessionJson(version: 1));
      final settings = InMemorySettingsRepository(
        initial: BathSystemPreference.zhuli,
      );
      await settings.saveHotwaterSession(legacy);
      final secure = InMemorySecureSessionRepository();
      final runtime = _runtime(
        adapter: adapter,
        settings: settings,
        secure: secure,
        session: legacy,
      );
      addTearDown(runtime.dispose);

      await runtime.ready;
      expect(runtime.state.hotwater.session?.phase,
          HotwaterSessionPhase.uncertain);
      expect(runtime.state.hotwaterStart.state, RuntimeTaskState.unavailable);
      expect(runtime.state.hotwaterStart.message, contains('解除本地状态'));

      expect(await runtime.clearUnreconciledHotwater(), isTrue);
      expect(await settings.loadHotwaterSession(), isNull);
      expect(await secure.loadHotwaterIsn(legacy.id), isNull);
      expect(runtime.state.hotwater.session, isNull);
      expect(runtime.state.homeTasks, isEmpty);
      expect(runtime.state.hotwaterStart.state, RuntimeTaskState.success);
      expect(runtime.state.hotwaterStart.message, contains('本地热水状态'));
      expect(adapter.startCalls, 0);
      expect(adapter.stopCalls, 0);
    });
  });

  group('hotwater reconciliation boundaries', () {
    test('known order and same-device baseline rules are conservative', () {
      final startedAt = DateTime(2026, 9, 10, 8).millisecondsSinceEpoch;
      final known = HotwaterSession(
        id: 'session-known',
        account: '13800000000',
        system: BathSystemPreference.zhuli,
        simulated: false,
        deviceId: 'device-1',
        startedAtMillis: startedAt,
        baselineOrderIds: const ['old-order'],
        phase: HotwaterSessionPhase.uncertain,
        orderId: 'new-order',
      );
      expect(
        known.hasNewConsumption(const [
          HotwaterHistoryUi(
            time: 'not-parseable',
            deviceId: 'other-device',
            amount: '金额未知',
            status: '状态未知',
            orderId: 'new-order',
          ),
        ]),
        isTrue,
      );

      final fallback = known.copyWith(orderId: '');
      HotwaterHistoryUi row(String device, String time, String order) =>
          HotwaterHistoryUi(
            time: time,
            deviceId: device,
            amount: '¥1.00',
            status: '进行中',
            orderId: order,
          );

      expect(
        fallback.hasNewConsumption(
          [row('device-1', '2026-09-10T08:00:01', 'fresh-order')],
        ),
        isTrue,
      );
      expect(
        fallback.hasNewConsumption(
          [row('other-device', '2026-09-10T08:00:01', 'other-order')],
        ),
        isFalse,
      );
      expect(
        fallback.hasNewConsumption(
          [row('device-1', '2026-09-10T07:59:59', 'before-order')],
        ),
        isFalse,
      );
      expect(
        fallback.hasNewConsumption(
          [row('device-1', '2026-09-10T08:00:01', 'old-order')],
        ),
        isFalse,
      );
    });

    test('account and default-system changes do not retarget a session',
        () async {
      final adapter = _TestHotwaterAdapter();
      final session = _activeSession();
      final settings = InMemorySettingsRepository(
        initial: BathSystemPreference.zhuli,
      );
      await settings.saveHotwaterSession(session);
      final secure = InMemorySecureSessionRepository();
      await secure.saveHotwaterIsn(session.id, 'isn-1');
      final runtime = _runtime(
        adapter: adapter,
        settings: settings,
        secure: secure,
        session: session,
      );
      addTearDown(runtime.dispose);

      await runtime.ready;
      final callsBeforeSystemChange = adapter.loadHistoryCalls;
      await runtime.setBathSystem(BathSystemPreference.shower798);
      await runtime.pollHotwaterStatusOnce();
      expect(adapter.loadHistoryCalls, callsBeforeSystemChange + 1);
      expect(runtime.state.hotwater.session?.id, session.id);
      expect(
          runtime.state.hotwater.session?.system, BathSystemPreference.zhuli);

      await runtime.loginZhuli('13900000000', 'password');
      final callsAfterAccountChange = adapter.loadHistoryCalls;
      await runtime.pollHotwaterStatusOnce();
      expect(adapter.loadHistoryCalls, callsAfterAccountChange);
      expect(runtime.state.hotwater.session?.account, '13800000000');
      expect(runtime.state.hotwaterStart.message, '请登录原账号确认热水状态');
    });

    test('polls are mutually exclusive and obsolete responses are discarded',
        () async {
      final adapter = _TestHotwaterAdapter();
      final session = _activeSession();
      final settings = InMemorySettingsRepository(
        initial: BathSystemPreference.zhuli,
      );
      await settings.saveHotwaterSession(session);
      final secure = InMemorySecureSessionRepository();
      await secure.saveHotwaterIsn(session.id, 'isn-1');
      final runtime = _runtime(
        adapter: adapter,
        settings: settings,
        secure: secure,
        session: session,
      );
      addTearDown(runtime.dispose);

      await runtime.ready;
      await Future<void>.delayed(Duration.zero);
      final pending = Completer<List<HotwaterHistoryUi>>();
      adapter.historyLoader = () => pending.future;
      final callsBefore = adapter.loadHistoryCalls;
      final firstPoll = runtime.pollHotwaterStatusOnce();
      final secondPoll = runtime.pollHotwaterStatusOnce();
      expect(adapter.loadHistoryCalls, callsBefore + 1);

      expect(
        await runtime.clearHotwaterSessionLocally(expected: session),
        isTrue,
      );
      pending.complete(const [
        HotwaterHistoryUi(
          time: '2026-09-10T09:00:00',
          deviceId: 'device-1',
          amount: '¥1.00',
          status: '已完成',
          orderId: 'new-order',
        ),
      ]);
      await Future.wait([firstPoll, secondPoll]);

      expect(runtime.state.hotwater.session, isNull);
      expect(runtime.state.hotwaterHistory, isEmpty);
      expect(runtime.state.homeTasks, isEmpty);
    });
  });

  testWidgets(
      'detail exposes a neutral local-clear result only for unreconciled state',
      (tester) async {
    final session = HotwaterSession(
      id: 'session-widget',
      account: '13800000000',
      system: BathSystemPreference.zhuli,
      simulated: false,
      deviceId: 'device-1',
      startedAtMillis: DateTime(2026, 9, 10).millisecondsSinceEpoch,
      baselineOrderIds: const [],
      phase: HotwaterSessionPhase.uncertain,
    );
    var clearCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HotwaterDetailScreen(
          state: ShuiHomeState(
            bathSystemPreference: BathSystemPreference.zhuli,
            hotwater: HotwaterState(
              running: true,
              session: session,
              start: const RuntimeActionStatus(
                state: RuntimeTaskState.unavailable,
                message: '热水状态待确认',
              ),
            ),
          ),
          onBack: () {},
          onStart: () {},
          onStop: () {},
          onClearLocal: () => clearCalls++,
        ),
      ),
    );

    expect(find.text('仅清除本地状态'), findsOneWidget);
    expect(find.text('热水状态待确认'), findsOneWidget);
    await tester.tap(find.text('仅清除本地状态'));
    expect(clearCalls, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: HotwaterDetailScreen(
          state: const ShuiHomeState(
            bathSystemPreference: BathSystemPreference.zhuli,
            hotwater: HotwaterState(
              start: RuntimeActionStatus(
                state: RuntimeTaskState.success,
                message: '已清除本地热水状态，设备状态仍需现场确认',
              ),
            ),
          ),
          onBack: () {},
          onStart: () {},
          onStop: () {},
        ),
      ),
    );
    expect(find.text('已清除本地热水状态，设备状态仍需现场确认'), findsOneWidget);
    expect(find.text('仅清除本地状态'), findsNothing);
  });

  testWidgets('shell local-clear confirmation supports cancel and confirm',
      (tester) async {
    final session = HotwaterSession(
      id: 'session-shell',
      account: '13800000000',
      system: BathSystemPreference.zhuli,
      simulated: false,
      deviceId: 'device-1',
      startedAtMillis: DateTime(2026, 9, 10).millisecondsSinceEpoch,
      baselineOrderIds: const [],
      phase: HotwaterSessionPhase.uncertain,
    );
    final settings = InMemorySettingsRepository(
      initial: BathSystemPreference.zhuli,
    );
    await settings.saveHotwaterSession(session);
    final secure = InMemorySecureSessionRepository();
    final adapter = _TestHotwaterAdapter();

    await tester.pumpWidget(
      MaterialApp(
        home: ShuiRuntimeScope(
          settings: settings,
          secure: secure,
          hotwater: adapter,
          clock: FixedLiveClock(session.startedAtMillis),
          initial: PersistedSnapshot(
            bathSystem: BathSystemPreference.zhuli,
            permissionIntroSeen: true,
            zhuli: const ZhuliSession(
              phone: '13800000000',
              deviceCode: 'device-1',
            ),
            hotwaterSession: session,
          ),
          child: const ShuiShell(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('查看详情 ›'));
    await tester.pumpAndSettle();
    expect(find.text('仅清除本地状态'), findsOneWidget);

    await tester.tap(find.text('仅清除本地状态'));
    await tester.pumpAndSettle();
    expect(find.text('清除本地热水状态'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('清除本地热水状态'), findsNothing);
    expect(await settings.loadHotwaterSession(), isNotNull);

    await tester.tap(find.text('仅清除本地状态'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认清除'));
    await tester.pumpAndSettle();
    expect(await settings.loadHotwaterSession(), isNull);
    expect(adapter.startCalls, 0);
    expect(adapter.stopCalls, 0);
    expect(find.textContaining('已清除本地热水状态'), findsWidgets);
  });

  group('adapter progress contract', () {
    test('fake adapter reports the three startup boundaries in order',
        () async {
      final adapter = _TestHotwaterAdapter();
      final stages = <HotwaterStartStage>[];

      final result = await adapter.startHotwater(
        'device-1',
        onProgress: (progress) async => stages.add(progress.stage),
      );

      expect(stages, [
        HotwaterStartStage.controlReady,
        HotwaterStartStage.orderCreated,
        HotwaterStartStage.commandSent,
      ]);
      expect(result.orderId, 'order-1');
      expect(result.isn, 'isn-1');
    });

    test('real adapter reports commandSent before the BLE start write',
        () async {
      final events = <String>[];
      final adapter = RealZhuliAdapter(
        transport: _StartFlowTransport(),
        ble: _RecordingBleTransport(events),
        session: _zhuliSessionData,
        nonce: () => 'nonce',
        timestamp: () => 'timestamp',
      );

      await adapter.startHotwater(
        'device-1',
        onProgress: (progress) async {
          events.add('progress:${progress.stage.name}');
        },
      );

      expect(events, contains('progress:commandSent'));
      expect(
        events.indexOf('progress:commandSent'),
        lessThan(events.indexOf('write:aabb')),
      );
    });
  });
}

const _zhuliSessionData = ZhuliSessionData(
  platformToken: 'platform-token',
  userId: 'staff-1',
  identityCode: 'identity',
  serverAddr: 'https://example.com',
  serverAppId: 'server-app',
  serverId: 'server-id',
  secretKey: 'secret',
);

Map<String, dynamic> _sessionJson({required int version}) => {
      'version': version,
      'id': 'session-1',
      'account': '13800000000',
      'system': 'zhuli',
      'simulated': false,
      'deviceId': 'device-1',
      'startedAtMillis': DateTime(2026, 9, 10).millisecondsSinceEpoch,
      'baselineOrderIds': ['old-order'],
      if (version == 2) 'phase': 'active',
      if (version == 2) 'orderId': 'new-order',
    };

HotwaterSession _activeSession() => HotwaterSession(
      id: 'session-active',
      account: '13800000000',
      system: BathSystemPreference.zhuli,
      simulated: false,
      deviceId: 'device-1',
      startedAtMillis: DateTime(2026, 9, 10).millisecondsSinceEpoch,
      baselineOrderIds: const ['old-order'],
      phase: HotwaterSessionPhase.active,
      orderId: 'order-1',
    );

PersistedSnapshot _snapshot({HotwaterSession? session}) => PersistedSnapshot(
      bathSystem: BathSystemPreference.zhuli,
      permissionIntroSeen: true,
      zhuli: const ZhuliSession(
        phone: '13800000000',
        deviceCode: 'device-1',
      ),
      hotwaterSession: session,
    );

FakeShuiRuntime _runtime({
  required _TestHotwaterAdapter adapter,
  required InMemorySettingsRepository settings,
  required InMemorySecureSessionRepository secure,
  HotwaterSession? session,
}) {
  return FakeShuiRuntime(
    settings: settings,
    secure: secure,
    hotwater: adapter,
    clock: const FixedLiveClock(1789027200000),
    initial: _snapshot(session: session),
  );
}

class _TestHotwaterAdapter implements IHotwaterAdapter {
  _TestHotwaterAdapter({
    this.failBeforeDispatchOnce = false,
    this.loseResponseAfterDispatchOnce = false,
  });

  final bool failBeforeDispatchOnce;
  final bool loseResponseAfterDispatchOnce;
  int startCalls = 0;
  int stopCalls = 0;
  int loadHistoryCalls = 0;
  Future<List<HotwaterHistoryUi>> Function()? historyLoader;

  @override
  Future<ZhuliSessionData> loginZhuli(String phone, String password) async =>
      _zhuliSessionData;

  @override
  Future<HotwaterActionResult> startHotwater(
    String deviceId, {
    HotwaterStartProgressCallback? onProgress,
  }) async {
    startCalls++;
    if (failBeforeDispatchOnce && startCalls == 1) {
      throw const HotwaterException('未扫描到设备');
    }
    const isn = 'isn-1';
    const orderId = 'order-1';
    await onProgress?.call(const HotwaterStartProgress(
      stage: HotwaterStartStage.controlReady,
      isn: isn,
    ));
    await onProgress?.call(const HotwaterStartProgress(
      stage: HotwaterStartStage.orderCreated,
      isn: isn,
      orderId: orderId,
    ));
    await onProgress?.call(const HotwaterStartProgress(
      stage: HotwaterStartStage.commandSent,
      isn: isn,
      orderId: orderId,
    ));
    if (loseResponseAfterDispatchOnce && startCalls == 1) {
      throw const HotwaterException('启动响应超时');
    }
    return const HotwaterActionResult(
      deviceId: 'device-1',
      statusText: '热水启动完成，供应中',
      orderId: orderId,
      isn: isn,
    );
  }

  @override
  Future<HotwaterActionResult> stopHotwater(
    String deviceId, {
    String? isn,
  }) async {
    stopCalls++;
    return const HotwaterActionResult(
      deviceId: 'device-1',
      statusText: '热水已关闭',
    );
  }

  @override
  Future<HotwaterStatusResult> refreshHotwaterStatus(String deviceId) async =>
      const HotwaterStatusResult(running: true, statusText: '热水供应中');

  @override
  Future<List<HotwaterHistoryUi>> loadHistory() async {
    loadHistoryCalls++;
    final loader = historyLoader;
    return loader == null ? const <HotwaterHistoryUi>[] : await loader();
  }
}

class _StartFlowTransport implements ZhuliTransport {
  @override
  Future<List<dynamic>> getArray(ZhuliRequest request) async => const [];

  @override
  Future<Map<String, dynamic>> getObject(ZhuliRequest request) async {
    final path = Uri.parse(request.url).path;
    if (path.endsWith('/device/get_by_id')) {
      return {
        'ble_name': 'XN-device',
        'ble_mac': '00:11:22:33:44:55',
        'device_type': '3',
      };
    }
    if (path.endsWith('/heart_shark_response')) {
      return {'isn': 'isn-1', 'ratecmd': '', 'result': '3'};
    }
    if (path.endsWith('/consume/create_order')) {
      return {'app_bytes': 'aabb', 'order_id': 'order-1'};
    }
    return <String, dynamic>{};
  }

  @override
  Future<String> getString(ZhuliRequest request) async {
    final path = Uri.parse(request.url).path;
    if (path.endsWith('/create_hand_shake_cmd')) return '0102';
    throw StateError('Unexpected string endpoint: $path');
  }
}

class _RecordingBleTransport implements BleTransport {
  _RecordingBleTransport(this.events);

  final List<String> events;

  @override
  Future<ZhuliBleConnection> scanAndConnect({
    required String bleName,
    required String bleMac,
  }) async =>
      _RecordingBleConnection(events);
}

class _RecordingBleConnection implements ZhuliBleConnection {
  _RecordingBleConnection(this.events);

  final List<String> events;
  int notifyCount = 0;

  @override
  Future<void> writeHex(String hex) async => events.add('write:$hex');

  @override
  Future<String> awaitNotify({required List<int> expectedTypes}) async {
    final type = notifyCount++ == 0 ? 1 : 3;
    events.add('notify:$type');
    return '000$type';
  }

  @override
  Future<void> close() async {}
}
