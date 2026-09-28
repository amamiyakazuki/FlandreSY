import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flandresy/src/app/flandre_app.dart';
import 'package:flandresy/src/orders/orders_screen.dart';
import 'package:flandresy/src/shell/shui_shell.dart';
import 'package:flandresy/src/shell/shui_shell_chrome.dart';
import 'package:flandresy/src/data/account_session_repository.dart';
import 'package:flandresy/src/data/adapters/real_shower798_adapter.dart';
import 'package:flandresy/src/data/adapters/shower798_adapter.dart';
import 'package:flandresy/src/data/adapters/shower798_transport.dart';
import 'package:flandresy/src/data/adapters/ujing_adapter.dart';
import 'package:flandresy/src/data/adapters/ujing_http_adapter.dart';
import 'package:flandresy/src/data/adapters/ujing_transport.dart';
import 'package:flandresy/src/data/secure_session_repository.dart';
import 'package:flandresy/src/data/water_order_repository.dart';
import 'package:flandresy/src/runtime/fake_shui_runtime.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'package:flandresy/src/runtime/models/water_order.dart';

const _a = '13800000001';
const _b = '13800000002';

void main() {
  test('login cannot race a read-result persistence commit', () async {
    final transport = _UjingTransport();
    final repo = _DelayedOrderSave(_order(owner: _a));
    final runtime = FakeShuiRuntime(
        sessions: _sessions(),
        water: repo,
        ujing: UjingHttpAdapter(transport: transport, token: 'token-a'));
    addTearDown(runtime.dispose);
    await runtime.ready;
    await transport.detailStarted.future;
    final pending = runtime.refreshCurrentDrinkingWaterOrder();
    transport.detail.complete({'orderStatus': '0'});
    await repo.started.future;
    await runtime.loginUjing(_b, '1234');
    expect(runtime.state.ujingAccount?.mobile, _a);
    expect(transport.paths.where((p) => p == 'login'), isEmpty);
    repo.release.complete();
    await pending;
    expect((await repo.load())?.currentOrder?.ownerAccountKey, _a);
    await runtime.loginUjing(_b, '1234');
    expect(runtime.state.ujingAccount?.mobile, _b);
  });
  test('late 798 device auth failure cannot clear new adapter token', () async {
    final transport = _ShowerTransport()
      ..deviceGate = Completer<Map<String, dynamic>>();
    final adapter =
        RealShower798Adapter(transport: transport, token: 'old-token');
    final pending = adapter.loadDevices();
    final failure = expectLater(pending, throwsA(isA<Shower798Exception>()));
    await adapter.login(_b, '1234');
    transport.deviceGate!.complete({'data': {}});
    await failure;
    expect(adapter.lastToken, 'new-token');
  });
  testWidgets(
      'legacy order binds restored A without consent UI and only queries',
      (tester) async {
    final transport = _UjingTransport()..detail.complete({'orderStatus': '0'});
    final repo = InMemoryWaterOrderRepository(
        snapshot: WaterOrderSnapshot(currentOrder: _order()));
    transport.beforeDetail = () async {
      expect((await repo.load())?.currentOrder?.ownerAccountKey, _a);
    };
    await tester.pumpWidget(FlandreApp(
        sessions: _sessions(),
        water: repo,
        ujing: UjingHttpAdapter(transport: transport, token: 'token-a')));
    await tester.pumpAndSettle();
    final permission = find.text('好，开启权限');
    if (permission.evaluate().isNotEmpty) {
      await tester.tap(permission);
      await tester.pumpAndSettle();
    }
    tester
        .widget<WavyBottomBar>(find.byType(WavyBottomBar))
        .onTabSelected(MainTab.orders);
    await tester.pumpAndSettle();
    tester.widget<OrdersScreen>(find.byType(OrdersScreen)).onOpenDrinking();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('确认旧订单所属账号'), findsNothing);
    expect(find.text('绑定并查询'), findsNothing);
    expect((await repo.load())?.currentOrder?.ownerAccountKey, _a);
    expect(transport.paths, isNotEmpty);
    expect(transport.paths.every((p) => p == 'water/waterOrderDetail'), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  test('late order A 401 cannot invalidate logged-in B or discard A order',
      () async {
    final transport = _UjingTransport();
    final secure = InMemorySecureSessionRepository(ujingToken: 'token-a');
    final repo = InMemoryWaterOrderRepository(
        snapshot: WaterOrderSnapshot(currentOrder: _order(owner: _a)));
    final runtime = FakeShuiRuntime(
        sessions: _sessions(),
        secure: secure,
        water: repo,
        ujing: UjingHttpAdapter(transport: transport, token: 'token-a'));
    addTearDown(runtime.dispose);
    await runtime.ready;
    await transport.detailStarted.future;
    final pending = runtime.refreshCurrentDrinkingWaterOrder();
    await runtime.loginUjing(_b, '1234');
    transport.detail.completeError(
        const UjingException('old A unauthorized', authInvalid: true));
    await pending;
    expect(runtime.state.ujingAccount?.mobile, _b);
    expect(await secure.loadUjingToken(), 'token-$_b');
    expect(runtime.state.currentWaterOrder?.ownerAccountKey, _a);
    expect((await repo.load())?.currentOrder?.ownerAccountKey, _a);
    expect(runtime.state.waterOrder.isBusy, isFalse);
  });

  test('switching to B after migration never reassigns A order', () async {
    final transport = _UjingTransport()..detail.complete({'orderStatus': '0'});
    final repo = InMemoryWaterOrderRepository(
        snapshot: WaterOrderSnapshot(currentOrder: _order()));
    final runtime = FakeShuiRuntime(
        sessions: _sessions(),
        water: repo,
        ujing: UjingHttpAdapter(transport: transport, token: 'token-a'));
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.resumeUjingOrders();
    expect(runtime.state.currentWaterOrder?.ownerAccountKey, _a);
    final detailsBeforeSwitch = transport.paths.length;
    await runtime.loginUjing(_b, '1234');
    await runtime.resumeUjingOrders();
    await runtime.refreshCurrentDrinkingWaterOrder();
    expect(runtime.state.ujingAccount?.mobile, _b);
    expect(runtime.state.currentWaterOrder?.ownerAccountKey, _a);
    expect((await repo.load())?.currentOrder?.ownerAccountKey, _a);
    expect(transport.paths.skip(detailsBeforeSwitch), ['login']);
  });

  test('without a recent account legacy owner remains empty until login',
      () async {
    final transport = _UjingTransport()..detail.complete({'orderStatus': '0'});
    final repo = InMemoryWaterOrderRepository(
        snapshot: WaterOrderSnapshot(currentOrder: _order()));
    final runtime = FakeShuiRuntime(
        sessions: InMemoryAccountSessionRepository(),
        water: repo,
        ujing: UjingHttpAdapter(transport: transport));
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.pollWaterOrderOnce();
    await runtime.refreshCurrentDrinkingWaterOrder();
    await runtime.scanDrinkingWaterAndCreateOrder('new-device');
    expect(transport.paths, isEmpty);
    expect(runtime.state.currentWaterOrder?.orderId, 'legacy');
    expect((await repo.load())?.currentOrder?.ownerAccountKey, '');
    transport.beforeDetail = () async {
      expect((await repo.load())?.currentOrder?.ownerAccountKey, _a);
    };
    await runtime.loginUjing(_a, '1234');
    expect(runtime.state.currentWaterOrder?.ownerAccountKey, _a);
    expect((await repo.load())?.currentOrder?.ownerAccountKey, _a);
    expect(transport.paths.first, 'login');
    expect(transport.paths.skip(1), isNotEmpty);
    expect(transport.paths.skip(1).every((p) => p == 'water/waterOrderDetail'),
        isTrue);
  });

  test('legacy owner must finish persistence before first query', () async {
    final transport = _UjingTransport();
    final repo = _DelayedOrderSave(_order());
    final runtime = FakeShuiRuntime(
        sessions: _sessions(),
        water: repo,
        ujing: UjingHttpAdapter(transport: transport, token: 'token-a'));
    addTearDown(runtime.dispose);
    await repo.started.future;
    expect(runtime.state.currentWaterOrder?.ownerAccountKey, '');
    expect((await repo.load())?.currentOrder?.ownerAccountKey, '');
    expect(transport.paths, isEmpty);
    repo.release.complete();
    await runtime.ready;
    await transport.detailStarted.future;
    expect((await repo.load())?.currentOrder?.ownerAccountKey, _a);
    expect(transport.paths, ['water/waterOrderDetail']);
    transport.detail.complete({'orderStatus': '0'});
    await runtime.refreshCurrentDrinkingWaterOrder();
  });

  test('recent A metadata without token binds locally but never queries as B',
      () async {
    final transport = _UjingTransport();
    final repo = InMemoryWaterOrderRepository(
        snapshot: WaterOrderSnapshot(currentOrder: _order()));
    final runtime = FakeShuiRuntime(
        sessions: _sessions(),
        water: repo,
        ujing: UjingHttpAdapter(transport: transport));
    addTearDown(runtime.dispose);
    await runtime.ready;
    expect(runtime.state.ujingAccount, isNull);
    expect((await repo.load())?.currentOrder?.ownerAccountKey, _a);
    expect(transport.paths, isEmpty);
    await runtime.loginUjing(_b, '1234');
    expect(runtime.state.ujingAccount?.mobile, _b);
    expect(runtime.state.currentWaterOrder?.ownerAccountKey, _a);
    expect((await repo.load())?.currentOrder?.ownerAccountKey, _a);
    expect(transport.paths, ['login']);
  });

  test('failed auto-owner persistence leaves original order and sends no query',
      () async {
    final transport = _UjingTransport();
    final repo = _FailOrderSave(_order());
    final runtime = FakeShuiRuntime(
        sessions: _sessions(),
        water: repo,
        ujing: UjingHttpAdapter(transport: transport, token: 'token-a'));
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.resumeUjingOrders();
    expect(runtime.state.currentWaterOrder?.ownerAccountKey, '');
    expect((await repo.load())?.currentOrder?.ownerAccountKey, '');
    expect(runtime.state.currentWaterOrder?.orderId, 'legacy');
    expect(transport.paths, isEmpty);
    expect(runtime.state.waterOrder.isBusy, isFalse);
  });

  test('798 login succeeds but device load fails: no mixed identity remains',
      () async {
    final transport = _ShowerTransport()..deviceFailure = true;
    final adapter =
        RealShower798Adapter(transport: transport, token: 'old-token');
    final secure = InMemorySecureSessionRepository(shower798Token: 'old-token');
    final sessions = InMemoryAccountSessionRepository(
        shower798: const Shower798Persisted(
      account: Shower798AccountUi(mobile: _a, uid: 'a', eid: 'e'),
      devices: [
        Shower798DeviceUi(id: 'saved-device', name: '原设备', lastStatus: '待机')
      ],
      currentDeviceId: 'saved-device',
    ));
    final runtime =
        FakeShuiRuntime(sessions: sessions, secure: secure, shower798: adapter);
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.loginShower798(_b, '1234');
    expect(runtime.state.shower798Account, isNull);
    expect(adapter.lastToken, isNull);
    expect(await secure.loadShower798Token(), isNull);
    final retained = await sessions.loadShower798();
    expect(retained, isNotNull);
    expect(retained!.account.mobile, isEmpty);
    expect(retained.account.uid, isEmpty);
    expect(retained.account.eid, isEmpty);
    expect(retained.devices.single.id, 'saved-device');
    expect(retained.devices.single.name, '原设备');
    expect(retained.currentDeviceId, 'saved-device');
    expect(runtime.state.shower798Devices.single.id, 'saved-device');
    expect(runtime.state.currentShower798DeviceId, 'saved-device');
    expect(runtime.state.shower798Login.isBusy, isFalse);
    expect(runtime.hotwaterAuthChanging, isFalse);
  });

  test('hotwater controls during 798 login send no device commands', () async {
    final transport = _ShowerTransport()
      ..loginGate = Completer<Map<String, dynamic>>();
    final runtime =
        FakeShuiRuntime(shower798: RealShower798Adapter(transport: transport));
    addTearDown(runtime.dispose);
    await runtime.ready;
    final login = runtime.loginShower798(_b, '1234');
    await transport.loginStarted.future;
    await runtime.startShower798();
    await runtime.stopShower798();
    expect(transport.paths, ['acc/login']);
    expect(runtime.state.hotwaterStart.isBusy, isFalse);
    expect(runtime.state.hotwaterStop.isBusy, isFalse);
    transport.loginGate!.complete(_ShowerTransport.loginResult);
    await login;
    expect(transport.paths, ['acc/login', 'ui/app/master']);
  });
}

InMemoryAccountSessionRepository _sessions() =>
    InMemoryAccountSessionRepository(
        ujing: const UjingAccountUi(
            mobile: _a, userId: 'a', serviceSubjectId: 's'));

WaterOrderUi _order({String owner = ''}) => WaterOrderUi(
    orderId: 'legacy',
    orderNo: 'old',
    serviceSubjectName: '',
    storeName: '',
    deviceNo: 'device-a',
    orderStatus: '0',
    orderStatusName: '',
    statusRemark: '',
    warmWaterMl: 0,
    waterSeconds: 0,
    payment: 0,
    ownerAccountKey: owner);

class _UjingTransport implements UjingTransport {
  final paths = <String>[];
  final detailStarted = Completer<void>();
  final detail = Completer<Map<String, dynamic>>();
  Future<void> Function()? beforeDetail;
  @override
  Future<Map<String, dynamic>> send(UjingRequest request) async {
    paths.add(request.path);
    if (request.path == 'login') {
      final mobile = request.body!['mobile'];
      return {
        'token': 'token-$mobile',
        'mobile': mobile,
        'userId': mobile,
        'serviceSubjectId': 's'
      };
    }
    if (request.path == 'water/waterOrderDetail') {
      await beforeDetail?.call();
      if (!detailStarted.isCompleted) detailStarted.complete();
      return detail.future;
    }
    throw StateError('Unexpected endpoint ${request.path}');
  }
}

class _DelayedOrderSave extends InMemoryWaterOrderRepository {
  _DelayedOrderSave(WaterOrderUi order)
      : super(snapshot: WaterOrderSnapshot(currentOrder: order));
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> save(WaterOrderSnapshot snapshot) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    await super.save(snapshot);
  }
}

class _FailOrderSave extends InMemoryWaterOrderRepository {
  _FailOrderSave(WaterOrderUi order)
      : super(snapshot: WaterOrderSnapshot(currentOrder: order));
  @override
  Future<void> save(WaterOrderSnapshot snapshot) async =>
      throw StateError('storage failed');
}

class _ShowerTransport implements Shower798Transport {
  final paths = <String>[];
  final loginStarted = Completer<void>();
  Completer<Map<String, dynamic>>? loginGate;
  Completer<Map<String, dynamic>>? deviceGate;
  bool deviceFailure = false;
  static const loginResult = <String, dynamic>{
    'data': {
      'al': {'token': 'new-token', 'uid': 'b', 'eid': 'e'}
    }
  };
  @override
  Future<Map<String, dynamic>> send(Shower798Request request) async {
    paths.add(request.path);
    if (request.path == 'acc/login') {
      loginStarted.complete();
      if (loginGate != null) return loginGate!.future;
      return loginResult;
    }
    if (request.path == 'ui/app/master') {
      if (deviceFailure) throw const Shower798Exception('device list offline');
      if (deviceGate != null) return deviceGate!.future;
      return {
        'data': {'account': {}, 'favos': []}
      };
    }
    throw StateError('Unexpected device operation ${request.path}');
  }

  @override
  Future<String> getImageBase64(Shower798Request request) async => '';
}
