import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flandresy/src/data/adapters/ble_transport.dart';
import 'package:flandresy/src/data/adapters/hotwater_adapter.dart';
import 'package:flandresy/src/data/adapters/fake_shower798_adapter.dart';
import 'package:flandresy/src/data/adapters/real_zhuli_adapter.dart';
import 'package:flandresy/src/data/adapters/zhuli_transport.dart';
import 'package:flandresy/src/data/app_bootstrap.dart';
import 'package:flandresy/src/data/account_session_repository.dart';
import 'package:flandresy/src/home/cards/hot_water_card.dart';
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

    test('corrupt shared session is preserved and reported for boot recovery',
        () async {
      SharedPreferences.setMockInitialValues({
        'hotwater_session': '{"version":99}',
      });

      final settings = SharedPrefsSettingsRepository();

      await expectLater(
          settings.loadHotwaterSession(), throwsA(isA<FormatException>()));
      expect(
        (await SharedPreferences.getInstance()).getString('hotwater_session'),
        '{"version":99}',
      );
      expect(
          (await SharedPreferences.getInstance())
              .getString('hotwater_session_recovery_backup'),
          '{"version":99}');
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
      expect(runtime.state.hotwaterStart.message, contains('启动指令已发送'));
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
      expect(runtime.state.hotwaterStart.state, RuntimeTaskState.success);
      expect(runtime.state.hotwaterStart.message, '热水使用中');

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
    test('a matching completed order updates history without ending hotwater',
        () async {
      final adapter = _TestHotwaterAdapter()
        ..historyLoader = () async => const [_completedOrder];
      final runtime = _runtime(
        adapter: adapter,
        settings: InMemorySettingsRepository(),
        secure: InMemorySecureSessionRepository(),
        session: _activeSession(),
      );
      addTearDown(runtime.dispose);
      await runtime.ready;
      await runtime.pollHotwaterStatusOnce();
      expect(runtime.state.hotwaterHistory.single.orderId, 'order-1');
      expect(runtime.state.hotwaterRunning, isTrue);
      expect(runtime.state.hotwater.session?.id, 'session-active');
      expect(runtime.state.hotwaterStart.message, '热水使用中');
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
      expect(runtime.state.hotwaterStart.message, '热水使用中');
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

  group('manual controls and 40 minute restore', () {
    test('798 can stop without a local session and coalesces repeated start',
        () async {
      final adapter = _TestShowerAdapter();
      final runtime = FakeShuiRuntime(
        shower798: adapter,
        initial: const PersistedSnapshot(
          bathSystem: BathSystemPreference.shower798,
          shower798: Shower798Persisted(
            account: Shower798AccountUi(
                mobile: '13800000000', uid: 'uid', eid: 'eid'),
            currentDeviceId: 'device-798',
          ),
        ),
      );
      addTearDown(runtime.dispose);
      await runtime.ready;
      await runtime.stopShower798();
      expect(adapter.stops, 1);
      await runtime.startShower798();
      await runtime.startShower798();
      expect(adapter.starts, 1);
      await runtime.pollHotwaterStatusOnce();
      expect(adapter.idleQueries, 0);
      expect(runtime.state.hotwaterRunning, isTrue);
      await runtime.stopShower798();
      expect(adapter.stops, 2);
      expect(runtime.state.hotwaterRunning, isFalse);
    });

    test('session storage clear failure leaves the stop credential intact',
        () async {
      final session = _activeSession();
      final settings = _FailingClearSettings();
      await settings.saveHotwaterSession(session);
      final secure = InMemorySecureSessionRepository();
      await secure.saveHotwaterIsn(session.id, 'saved-isn');
      final runtime = _runtime(
          adapter: _TestHotwaterAdapter(),
          settings: settings,
          secure: secure,
          session: session);
      addTearDown(runtime.dispose);
      await runtime.ready;
      expect(await runtime.clearHotwaterSessionLocally(expected: session),
          isFalse);
      expect(await secure.loadHotwaterIsn(session.id), 'saved-isn');
      expect(runtime.state.hotwater.session?.id, session.id);
    });

    test(
        'auth failure on missing-credential refresh exits loading and permits login',
        () async {
      final adapter = _TestHotwaterAdapter()
        ..historyLoader = () async =>
            throw const HotwaterException('expired', authInvalid: true);
      final runtime = _runtime(
          adapter: adapter,
          settings: InMemorySettingsRepository(),
          secure: InMemorySecureSessionRepository());
      addTearDown(runtime.dispose);
      await runtime.ready;
      await runtime.stopHotwater();
      expect(runtime.state.hotwaterStop.isBusy, isFalse);
      expect(runtime.state.hotwaterStop.state, RuntimeTaskState.loginRequired);
      await runtime.loginZhuli('13800000000', 'password');
      expect(runtime.state.zhuli.phone, '13800000000');
    });

    testWidgets(
        'remaining in foreground does not run the removed 10 second or one hour checks',
        (tester) async {
      final adapter = _TestHotwaterAdapter();
      final runtime = _runtime(
          adapter: adapter,
          settings: InMemorySettingsRepository(),
          secure: InMemorySecureSessionRepository(),
          session: _activeSession());
      await tester.pump();
      await runtime.ready;
      await tester.pump(const Duration(hours: 2));
      expect(adapter.loadHistoryCalls, 0);
      expect(runtime.state.hotwaterRunning, isTrue);
      runtime.dispose();
    });

    for (final preloaded in [true, false]) {
      for (final elapsed in [
        const Duration(minutes: 39, seconds: 59),
        const Duration(minutes: 40),
        const Duration(minutes: 40, milliseconds: 1),
      ]) {
        test('restore $elapsed with preloaded=$preloaded', () async {
          final session = _activeSession();
          final settings =
              InMemorySettingsRepository(initial: BathSystemPreference.zhuli);
          await settings.saveHotwaterSession(session);
          final adapter = _TestHotwaterAdapter()
            ..historyLoader = () async => const [_completedOrder];
          final runtime = _runtime(
            adapter: adapter,
            settings: settings,
            secure: InMemorySecureSessionRepository(),
            session: session,
            preloaded: preloaded,
            clock: FixedLiveClock(
                session.startedAtMillis + elapsed.inMilliseconds),
          );
          addTearDown(runtime.dispose);
          await runtime.ready;
          await Future<void>.delayed(Duration.zero);
          final expired = elapsed > const Duration(minutes: 40);
          expect(runtime.state.hotwaterRunning, !expired);
          expect(runtime.state.hotwater.session == null, expired);
          expect(await settings.loadHotwaterSession() == null, expired);
          expect(
              runtime.state.hotwaterStart.message, expired ? '热水待启动' : '热水使用中');
          expect(adapter.loadHistoryCalls, expired ? 1 : 0);
          if (expired) {
            expect(runtime.state.hotwaterHistory, const [_completedOrder]);
          }
          expect(adapter.startCalls, 0);
          expect(adapter.stopCalls, 0);
        });
      }
    }

    test('expired recovery stays idle when refreshing orders fails', () async {
      final session = _activeSession();
      final adapter = _TestHotwaterAdapter()
        ..historyLoader = () async => throw TimeoutException('offline');
      final runtime = _runtime(
        adapter: adapter,
        settings: InMemorySettingsRepository(),
        secure: InMemorySecureSessionRepository(),
        session: session,
        clock: FixedLiveClock(session.startedAtMillis +
            const Duration(minutes: 41).inMilliseconds),
      );
      addTearDown(runtime.dispose);
      await runtime.ready;
      await Future<void>.delayed(Duration.zero);
      expect(runtime.state.hotwaterRunning, isFalse);
      expect(runtime.state.hotwaterStart.message, '热水待启动');
      expect(
          runtime.state.hotwater.historyStatus.state, RuntimeTaskState.failure);
      adapter.historyLoader = () async => const [_completedOrder];
      await runtime.stopHotwater();
      expect(runtime.state.hotwaterHistory, const [_completedOrder]);
      expect(runtime.state.hotwaterStop.message, '订单已更新');
      expect(adapter.stopCalls, 0);
    });

    test(
        'foreground resume applies the window and does not restart periodic polling',
        () async {
      final session = _activeSession();
      final clock = _MutableClock(session.startedAtMillis);
      final adapter = _TestHotwaterAdapter();
      final runtime = _runtime(
        adapter: adapter,
        settings: InMemorySettingsRepository(),
        secure: InMemorySecureSessionRepository(),
        session: session,
        clock: clock,
      );
      addTearDown(runtime.dispose);
      await runtime.ready;
      runtime.setPollingPaused(true);
      clock.millis += const Duration(minutes: 41).inMilliseconds;
      runtime.setPollingPaused(false);
      await Future<void>.delayed(Duration.zero);
      expect(runtime.state.hotwaterRunning, isFalse);
      expect(runtime.state.hotwater.session, isNull);
      expect(adapter.loadHistoryCalls, 1);
      expect(adapter.stopCalls, 0);
    });

    for (final withSession in [false, true]) {
      test('stop without isn refreshes orders, session=$withSession', () async {
        final adapter = _TestHotwaterAdapter()
          ..historyLoader = () async => const [_completedOrder];
        final runtime = _runtime(
          adapter: adapter,
          settings: InMemorySettingsRepository(),
          secure: InMemorySecureSessionRepository(),
          session: withSession ? _activeSession() : null,
        );
        addTearDown(runtime.dispose);
        await runtime.ready;
        await runtime.stopHotwater();
        expect(adapter.loadHistoryCalls, 1);
        expect(adapter.stopCalls, 0);
        expect(runtime.state.hotwaterHistory, const [_completedOrder]);
        expect(runtime.state.hotwaterStop.message, '订单已更新');
        expect(runtime.state.hotwaterRunning, withSession);
        adapter.historyLoader = () async => throw TimeoutException('offline');
        await runtime.stopHotwater();
        expect(runtime.state.hotwaterHistory, const [_completedOrder]);
        expect(runtime.state.hotwaterStop.state, RuntimeTaskState.failure);
        await runtime.startHotwater();
        expect(adapter.startCalls, withSession ? 0 : 1);
        expect(runtime.state.hotwaterRunning, isTrue);
      });
    }

    test('start again retains the original active session and credential',
        () async {
      final adapter = _TestHotwaterAdapter()
        ..historyLoader =
            () async => throw StateError('must not query before starting');
      final secure = InMemorySecureSessionRepository();
      final clock = _MutableClock(_activeSession().startedAtMillis);
      final runtime = _runtime(
          adapter: adapter,
          settings: InMemorySettingsRepository(),
          secure: secure,
          clock: clock);
      addTearDown(runtime.dispose);
      await runtime.ready;
      await runtime.startHotwater();
      final first = runtime.state.hotwater.session!;
      clock.millis += const Duration(minutes: 10).inMilliseconds;
      await runtime.startHotwater();
      expect(adapter.startCalls, 1);
      expect(adapter.loadHistoryCalls, 0);
      expect(runtime.state.hotwater.session!.id, first.id);
      expect(runtime.state.hotwater.session!.startedAtMillis,
          first.startedAtMillis);
      expect(await secure.loadHotwaterIsn(first.id), 'isn-1');
      expect(await secure.loadHotwaterIsn(runtime.state.hotwater.session!.id),
          'isn-1');
    });

    test('an active session bypasses start protocol and keeps stop credential',
        () async {
      final adapter = _TestHotwaterAdapter(failBeforeDispatchOnce: true);
      final session = _activeSession();
      final secure = InMemorySecureSessionRepository();
      await secure.saveHotwaterIsn(session.id, 'previous-isn');
      final runtime = _runtime(
          adapter: adapter,
          settings: InMemorySettingsRepository(),
          secure: secure,
          session: session);
      addTearDown(runtime.dispose);
      await runtime.ready;
      await runtime.startHotwater();
      expect(runtime.state.hotwater.session?.id, session.id);
      expect(adapter.startCalls, 0);
      expect(runtime.state.hotwaterRunning, isTrue);
      expect(await secure.loadHotwaterIsn(session.id), 'previous-isn');
      await runtime.stopHotwater();
      expect(adapter.lastStopIsn, 'previous-isn');
      expect(runtime.state.hotwater.session, isNull);
    });

    test(
        'stop clicked during start is queued and repeated clicks are coalesced',
        () async {
      final gate = Completer<void>();
      final adapter = _TestHotwaterAdapter()..startGate = gate;
      final runtime = _runtime(
          adapter: adapter,
          settings: InMemorySettingsRepository(),
          secure: InMemorySecureSessionRepository());
      addTearDown(runtime.dispose);
      await runtime.ready;
      final start = runtime.startHotwater();
      final duplicateStart = runtime.startHotwater();
      await Future<void>.delayed(Duration.zero);
      final stop = runtime.stopHotwater();
      final duplicateStop = runtime.stopHotwater();
      await Future<void>.delayed(Duration.zero);
      expect(adapter.startCalls, 1);
      expect(adapter.stopCalls, 0);
      gate.complete();
      await Future.wait([start, duplicateStart, stop, duplicateStop]);
      expect(adapter.startCalls, 1);
      expect(adapter.stopCalls, 1);
      expect(adapter.lastStopIsn, 'isn-1');
      expect(runtime.state.hotwaterRunning, isFalse);
      expect(runtime.state.hotwaterStop.message, '热水已关闭');
      expect(adapter.loadHistoryCalls, 1);
    });

    test('double start with restore interleaved sends only one start',
        () async {
      final gate = Completer<void>();
      final adapter = _TestHotwaterAdapter()..startGate = gate;
      final runtime = _runtime(
          adapter: adapter,
          settings: InMemorySettingsRepository(),
          secure: InMemorySecureSessionRepository());
      addTearDown(runtime.dispose);
      await runtime.ready;
      final first = runtime.startHotwater();
      await Future<void>.delayed(Duration.zero);
      final resume = runtime.resumeHotwaterSession();
      final second = runtime.startHotwater();
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await Future.wait([first, resume, second]);
      expect(adapter.startCalls, 1);
      expect(runtime.state.hotwaterRunning, isTrue);
    });

    test('start stop start preserves all three control intents', () async {
      final gate = Completer<void>();
      final adapter = _TestHotwaterAdapter()..startGate = gate;
      final runtime = _runtime(
          adapter: adapter,
          settings: InMemorySettingsRepository(),
          secure: InMemorySecureSessionRepository());
      addTearDown(runtime.dispose);
      await runtime.ready;
      final first = runtime.startHotwater();
      await Future<void>.delayed(Duration.zero);
      final stop = runtime.stopHotwater();
      final second = runtime.startHotwater();
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await Future.wait([first, stop, second]);
      expect(adapter.startCalls, 2);
      expect(adapter.stopCalls, 1);
      expect(runtime.state.hotwaterRunning, isTrue);
    });

    for (final failure in ['response', 'stop', 'storage']) {
      test('start after $failure failure does not repeat device command',
          () async {
        final adapter = _TestHotwaterAdapter(
            loseResponseAfterDispatchOnce: failure == 'response')
          ..failStop = failure == 'stop';
        final secure = InMemorySecureSessionRepository();
        final runtime = _runtime(
            adapter: adapter,
            settings: failure == 'storage'
                ? _FailingDispatchedSettings()
                : InMemorySettingsRepository(),
            secure: secure);
        addTearDown(runtime.dispose);
        await runtime.ready;
        await runtime.startHotwater();
        final original = runtime.state.hotwater.session!;
        if (failure == 'stop') await runtime.stopHotwater();
        await runtime.startHotwater();
        expect(adapter.startCalls, 1);
        expect(runtime.state.hotwater.session!.id, original.id);
        expect(runtime.state.hotwater.session!.startedAtMillis,
            original.startedAtMillis);
        expect(runtime.state.hotwater.session!.mayHaveStarted, isTrue);
        expect(await secure.loadHotwaterIsn(original.id), 'isn-1');
        if (failure != 'stop') {
          expect(runtime.state.hotwater.session!.phase,
              HotwaterSessionPhase.uncertain);
          await runtime.stopHotwater();
          expect(adapter.lastStopIsn, 'isn-1');
        }
      });
    }

    test('restore queued during a start does not clear an in-flight session',
        () async {
      final gate = Completer<void>();
      final adapter = _TestHotwaterAdapter()..startGate = gate;
      final runtime = _runtime(
          adapter: adapter,
          settings: InMemorySettingsRepository(),
          secure: InMemorySecureSessionRepository());
      addTearDown(runtime.dispose);
      await runtime.ready;
      final start = runtime.startHotwater();
      await Future<void>.delayed(Duration.zero);
      final resume = runtime.resumeHotwaterSession();
      expect(runtime.state.hotwater.session, isNotNull);
      gate.complete();
      await Future.wait([start, resume]);
      expect(
          runtime.state.hotwater.session?.phase, HotwaterSessionPhase.active);
      expect(runtime.state.hotwaterRunning, isTrue);
    });

    testWidgets('stop failure notice clears without changing the running title',
        (tester) async {
      final adapter = _TestHotwaterAdapter()..failStop = true;
      final runtime = _runtime(
          adapter: adapter,
          settings: InMemorySettingsRepository(),
          secure: InMemorySecureSessionRepository());
      await tester.pump();
      await runtime.ready;
      final start = runtime.startHotwater();
      await tester.pump();
      await start;
      final stop = runtime.stopHotwater();
      await tester.pump();
      await stop;
      expect(runtime.state.hotwaterStop.state, RuntimeTaskState.failure);
      await tester.pump(const Duration(seconds: 3));
      expect(runtime.state.hotwaterRunning, isTrue);
      expect(runtime.state.hotwaterStart.message, '热水使用中');
      runtime.dispose();
    });

    for (final busy in [false, true]) {
      for (final running in [false, true]) {
        testWidgets(
            'both home and detail buttons accept taps: busy=$busy running=$running',
            (tester) async {
          final state = ShuiHomeState(
            bathSystemPreference: BathSystemPreference.zhuli,
            hotwater: HotwaterState(
              running: running,
              session: running ? _activeSession() : null,
              start: RuntimeActionStatus(
                  state:
                      busy ? RuntimeTaskState.loading : RuntimeTaskState.idle),
            ),
          );
          var starts = 0;
          var stops = 0;
          for (final detail in [false, true]) {
            await tester.pumpWidget(MaterialApp(
                home: detail
                    ? HotwaterDetailScreen(
                        state: state,
                        onBack: () {},
                        onStart: () => starts++,
                        onStop: () => stops++)
                    : Scaffold(
                        body: HotWaterCard(
                            state: state,
                            onStartHotwater: () => starts++,
                            onStopHotwater: () => stops++,
                            onSwitchBathSystem: () {},
                            onOpenDetail: () {}))));
            await tester.tap(find.text('启动热水'));
            await tester.tap(find.text('停止热水'));
          }
          expect(starts, 2);
          expect(stops, 2);
        });
      }
    }
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

const _completedOrder = HotwaterHistoryUi(
  time: '2026-09-10T00:10:00',
  deviceId: 'device-1',
  amount: '¥1.00',
  status: '已完成',
  orderId: 'order-1',
);

class _MutableClock implements LiveClock {
  _MutableClock(this.millis);
  int millis;
  @override
  int nowMillis() => millis;
}

class _FailingClearSettings extends InMemorySettingsRepository {
  @override
  Future<void> saveHotwaterSession(HotwaterSession? session) async {
    if (session == null) throw StateError('storage unavailable');
    await super.saveHotwaterSession(session);
  }
}

class _FailingDispatchedSettings extends InMemorySettingsRepository {
  @override
  Future<void> saveHotwaterSession(HotwaterSession? session) async {
    if (session?.mayHaveStarted == true) {
      throw StateError('storage unavailable');
    }
    await super.saveHotwaterSession(session);
  }
}

class _TestShowerAdapter extends FakeShower798Adapter {
  int starts = 0;
  int stops = 0;
  int idleQueries = 0;
  @override
  Future<void> startShower(String deviceId) async => starts++;
  @override
  Future<void> stopShower(String deviceId) async => stops++;
  @override
  Future<bool> isDeviceIdle(String deviceId) async {
    idleQueries++;
    return true;
  }
}

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
  LiveClock? clock,
  bool preloaded = true,
}) {
  return FakeShuiRuntime(
    settings: settings,
    secure: secure,
    hotwater: adapter,
    clock: clock ?? FixedLiveClock(session?.startedAtMillis ?? 1789027200000),
    sessions: InMemoryAccountSessionRepository(zhuli: _snapshot().zhuli),
    initial: preloaded ? _snapshot(session: session) : null,
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
  Completer<void>? startGate;
  bool failStop = false;
  String? lastStopIsn;

  @override
  Future<ZhuliSessionData> loginZhuli(String phone, String password) async =>
      _zhuliSessionData;

  @override
  Future<HotwaterActionResult> startHotwater(
    String deviceId, {
    HotwaterStartProgressCallback? onProgress,
  }) async {
    startCalls++;
    await startGate?.future;
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
    lastStopIsn = isn;
    if (failStop) throw const HotwaterException('关水请求失败');
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
  Future<String> writeHexAndAwait(String hex,
      {required List<int> expectedTypes}) async {
    await writeHex(hex);
    return await awaitNotify(expectedTypes: expectedTypes);
  }

  @override
  Future<String> awaitNotify({required List<int> expectedTypes}) async {
    final type = notifyCount++ == 0 ? 1 : 3;
    events.add('notify:$type');
    return '000$type';
  }

  @override
  Future<void> close() async {}
}
