import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/adapters/io_ujing_transport.dart';
import 'package:flandresy/src/data/adapters/io_shower798_transport.dart';
import 'package:flandresy/src/data/adapters/ujing_http_adapter.dart';
import 'package:flandresy/src/data/adapters/real_shower798_adapter.dart';
import 'package:flandresy/src/data/account_session_repository.dart';
import 'package:flandresy/src/data/settings_repository.dart';
import 'package:flandresy/src/data/secure_session_repository.dart';
import 'package:flandresy/src/data/washer_history_repository.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'package:flandresy/src/runtime/models/washer_order.dart';
import 'package:flandresy/src/runtime/hotwater_state.dart';
import 'support/test_runtime.dart';
import 'support/fake_payment_launcher.dart';
import 'support/loopback_service.dart';

const _account = UjingAccountUi(
    mobile: 'test-account', userId: 'user-a', serviceSubjectId: 'school');
const _shower = Shower798Persisted(
    account:
        Shower798AccountUi(mobile: 'test-account', uid: 'user-a', eid: 'e'),
    devices: [Shower798DeviceUi(id: 'device-a', name: 'test-device')],
    currentDeviceId: 'device-a');

void main() {
  for (final operation in ['cancel', 'start', 'stop']) {
    for (final badDetail in [false, true]) {
      if (operation == 'cancel' && badDetail) continue;
      test(
          'washer $operation preserves disk record on ${badDetail ? 'bad detail after ACK' : 'bad ACK'}',
          () async {
        final server = await LoopbackService.start();
        addTearDown(server.close);
        final status = operation == 'cancel'
            ? '10'
            : operation == 'start'
                ? '20'
                : '40';
        var mutated = false;
        server.respond = (path) {
          if (path.endsWith('/detail')) {
            return {
              'code': 0,
              'data': mutated && badDetail ? {} : {'status': status}
            };
          }
          mutated = true;
          return badDetail ? {'code': 0} : {};
        };
        final order = WasherOrderUi(
            orderId: 'order-a',
            deviceNo: 'device-a',
            statusText: 'original',
            payPrice: '3',
            status: status,
            ownerAccountKey: _account.mobile);
        final repo = InMemoryWasherHistoryRepository(currentOrder: order);
        final runtime = _washerRuntime(server, repo);
        addTearDown(runtime.dispose);
        await runtime.ready;
        await runtime.refreshCurrentWasherOrder();
        server.paths.clear();
        switch (operation) {
          case 'cancel':
            await runtime.cancelCurrentWasherOrder();
          case 'start':
            await runtime.startCurrentWasherOrder();
          case 'stop':
            await runtime.stopCurrentWasherOrder();
        }
        final saved = (await repo.loadCurrentOrder())!;
        expect(saved.orderId, order.orderId);
        expect(saved.ownerAccountKey, order.ownerAccountKey);
        expect(saved.status, status);
        expect(runtime.state.washer.currentOrder?.status, status);
        expect(
            runtime.state.washer.washerOrder.state, RuntimeTaskState.failure);
        expect(runtime.state.washer.washerOrder.message, contains('未确认'));
        expect(server.paths.where((p) => !p.endsWith('/detail')), hasLength(1));
        final restored = _washerRuntime(server, repo);
        addTearDown(restored.dispose);
        await restored.ready;
        await restored.refreshCurrentWasherOrder();
        expect(restored.state.washer.currentOrder?.orderId, order.orderId);
        expect(restored.state.washer.currentOrder?.ownerAccountKey,
            order.ownerAccountKey);
        expect(restored.state.washer.currentOrder?.status, status);
        expect(server.paths.where((p) => !p.endsWith('/detail')), hasLength(1));
      });
    }
  }
  test('washer explicit empty ACK cancels once and persists terminal history',
      () async {
    final server = await LoopbackService.start();
    addTearDown(server.close);
    server.respond = (path) => path.endsWith('/detail')
        ? {
            'code': 0,
            'data': {'status': '10'}
          }
        : {'code': 0};
    final repo = InMemoryWasherHistoryRepository(
        currentOrder: const WasherOrderUi(
            orderId: 'order-a',
            deviceNo: 'device-a',
            statusText: '待支付',
            payPrice: '3',
            status: '10',
            ownerAccountKey: 'test-account'));
    final runtime = _washerRuntime(server, repo);
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.refreshCurrentWasherOrder();
    await runtime.cancelCurrentWasherOrder();
    expect(await repo.loadCurrentOrder(), isNull);
    expect((await repo.loadHistory())!.single.status, 'cancelled');
    expect(server.paths.where((p) => p.endsWith('/cancel')), hasLength(1));
  });

  test(
      '798 malformed start/stop preserve uncertain session through restart, never auto resend',
      () async {
    final server = await LoopbackService.start();
    addTearDown(server.close);
    server.response = {};
    final settings =
        InMemorySettingsRepository(initial: BathSystemPreference.shower798);
    final secure =
        InMemorySecureSessionRepository(shower798Token: 'test-token');
    final runtime = _showerRuntime(server, settings, secure);
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.startShower798();
    final saved = (await settings.loadHotwaterSession())!;
    expect(saved.phase, HotwaterSessionPhase.uncertain);
    expect(runtime.state.hotwaterStart.state, isNot(RuntimeTaskState.success));
    await runtime.startShower798();
    expect(server.paths, ['dev/start']);
    await runtime.stopShower798();
    expect(runtime.state.hotwaterStop.state, RuntimeTaskState.failure);
    expect(runtime.state.hotwaterStop.message, contains('未确认'));
    expect((await settings.loadHotwaterSession())?.id, saved.id);
    expect(await secure.loadShower798Token(), 'test-token');
    final restored = _showerRuntime(server, settings, secure);
    addTearDown(restored.dispose);
    await restored.ready;
    await restored.resumeHotwaterSession();
    expect(restored.state.hotwater.session?.id, saved.id);
    expect(restored.state.hotwater.session?.account, saved.account);
    expect(restored.state.hotwaterStart.message, contains('待确认'));
    expect(server.paths, ['dev/start', 'dev/end']);
    server.response = {'code': 0};
    await restored.stopShower798();
    expect(await settings.loadHotwaterSession(), isNull);
    expect(restored.state.hotwaterStop.message, '停止请求已确认，请核对设备');
    expect(server.paths, ['dev/start', 'dev/end', 'dev/end']);
  });
  test(
      '798 explicit ACK preserves manual start/stop and reports only request confirmation',
      () async {
    final server = await LoopbackService.start();
    addTearDown(server.close);
    final settings =
        InMemorySettingsRepository(initial: BathSystemPreference.shower798);
    final runtime =
        _showerRuntime(server, settings, InMemorySecureSessionRepository());
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.startShower798();
    await runtime.startShower798();
    expect(runtime.state.hotwater.session?.phase, HotwaterSessionPhase.active);
    expect(runtime.state.hotwaterStart.message, '启动请求已确认，请核对设备');
    expect(server.paths, ['dev/start']);
    await runtime.stopShower798();
    expect(runtime.state.hotwater.session, isNull);
    expect(runtime.state.hotwaterStop.message, '停止请求已确认，请核对设备');
    expect(runtime.state.shower798Devices.single.lastStatus, '停止请求已确认');
    expect(server.paths, ['dev/start', 'dev/end']);
  });
  for (final kind in [AccountKind.ujing, AccountKind.shower798]) {
    test(
        '$kind malformed probe preserves credentials; explicit 401 invalidates',
        () async {
      final server = await LoopbackService.start();
      addTearDown(server.close);
      server.response = {};
      final secure = InMemorySecureSessionRepository(
          ujingToken: 'test-token', shower798Token: 'test-token');
      final runtime = TestRuntime(
          sessions: InMemoryAccountSessionRepository(
              ujing: _account, shower798: _shower),
          secure: secure,
          ujing: _ujing(server),
          shower798: _adapter(server));
      addTearDown(runtime.dispose);
      await runtime.ready;
      for (final payload in [
        {},
        {'code': 0, 'data': {}},
        {'code': '0'}
      ]) {
        server.response = payload;
        await runtime.checkAccountStatus(kind);
        expect(runtime.state.account.availability[kind]?.state,
            RuntimeTaskState.unavailable);
        expect(await secure.loadUjingToken(), 'test-token');
        expect(await secure.loadShower798Token(), 'test-token');
      }
      server.status = 401;
      await runtime.checkAccountStatus(kind);
      expect(runtime.state.account.availability[kind]?.state,
          RuntimeTaskState.loginRequired);
      expect(
          kind == AccountKind.ujing
              ? await secure.loadUjingToken()
              : await secure.loadShower798Token(),
          isNull);
      expect(
          server.paths.every((p) =>
              p == 'ui/app/master' ||
              p == 'app/water/serviceSubject/currentInfo'),
          isTrue);
    });
  }
}

UjingHttpAdapter _ujing(LoopbackService server) => UjingHttpAdapter(
    transport: IoUjingTransport(baseUrl: server.url, client: server.client),
    token: 'test-token',
    launcher: const FakePaymentLauncher());
RealShower798Adapter _adapter(LoopbackService server) => RealShower798Adapter(
    transport: IoShower798Transport(
        baseUrl: server.url.substring(0, server.url.length - 1),
        client: server.client),
    token: 'test-token');
TestRuntime _washerRuntime(
        LoopbackService server, InMemoryWasherHistoryRepository repo) =>
    TestRuntime(
        sessions: InMemoryAccountSessionRepository(ujing: _account),
        washerHistory: repo,
        ujing: _ujing(server));
TestRuntime _showerRuntime(
        LoopbackService server,
        InMemorySettingsRepository settings,
        InMemorySecureSessionRepository secure) =>
    TestRuntime(
        sessions: InMemoryAccountSessionRepository(shower798: _shower),
        settings: settings,
        secure: secure,
        shower798: _adapter(server));
