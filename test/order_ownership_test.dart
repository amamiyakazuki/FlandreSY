import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/account_session_repository.dart';
import 'package:flandresy/src/data/adapters/fake_ujing_adapter.dart';
import 'package:flandresy/src/data/adapters/ujing_adapter.dart';
import 'package:flandresy/src/data/adapters/ujing_http_adapter.dart';
import 'package:flandresy/src/data/adapters/ujing_transport.dart';
import 'package:flandresy/src/data/washer_history_repository.dart';
import 'package:flandresy/src/data/water_order_repository.dart';
import 'package:flandresy/src/runtime/fake_shui_runtime.dart';
import 'package:flandresy/src/runtime/shui_runtime_base.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'package:flandresy/src/runtime/models/washer_order.dart';
import 'package:flandresy/src/runtime/models/water_order.dart'
    hide formatFenAmount;

const _account =
    UjingAccountUi(mobile: 'account-a', userId: 'a', serviceSubjectId: 's');
const _water = WaterOrderUi(
    orderId: 'water-1',
    orderNo: 'water-no',
    serviceSubjectName: '',
    storeName: '',
    deviceNo: 'd1',
    orderStatus: '0',
    orderStatusName: '未完成',
    statusRemark: '',
    warmWaterMl: 0,
    waterSeconds: 0,
    payment: 0);
const _washer = WasherOrderUi(
    orderId: 'wash-1',
    deviceNo: 'w1',
    statusText: '待支付',
    payPrice: '1',
    status: '10');
const _program = WasherProgramUi(
    deviceId: 'w',
    deviceNo: 'w1',
    deviceTypeName: '',
    storeName: '',
    status: '',
    reason: '',
    createOrderEnabled: true,
    defaultWashModelId: 1,
    models: []);

void main() {
  test(
      'retention save failure preserves loginRequired and warns not to close app',
      () async {
    final adapter = _Adapter()..createGate = Completer<WasherOrderUi>();
    final runtime = await _runtime(adapter, washer: _FailWasher());
    await runtime.scanWasher('qr');
    final creating =
        runtime.createWasherOrder(washModelId: 1, temperatureId: 1);
    await Future<void>.delayed(Duration.zero);
    await runtime.handleAuthInvalidation(AuthService.ujing,
        expectedEpoch: runtime.ujingAuthEpoch);
    adapter.createGate!.complete(_washer);
    await creating;
    expect(runtime.state.currentWasherOrder!.orderId, 'wash-1');
    expect(runtime.state.washerOrder.state, RuntimeTaskState.loginRequired);
    expect(runtime.state.washerOrder.message, contains('请勿关闭 App'));

    final waterAdapter = _Adapter()
      ..waterCreateGate = Completer<WaterPrepareResult>();
    final waterRuntime = await _runtime(waterAdapter, water: _FailWater());
    final waterCreating = waterRuntime.scanDrinkingWaterAndCreateOrder('qr');
    await Future<void>.delayed(Duration.zero);
    await waterRuntime.handleAuthInvalidation(AuthService.ujing,
        expectedEpoch: waterRuntime.ujingAuthEpoch);
    waterAdapter.waterCreateGate!.complete(const WaterPrepareResult(
        ready: WaterReadyUi(
            cd: 'x',
            serviceSubjectId: '',
            serviceSubjectName: '',
            storeId: '',
            balanceFen: 1000),
        order: _water));
    await waterCreating;
    expect(waterRuntime.state.currentWaterOrder!.orderId, 'water-1');
    expect(waterRuntime.state.waterOrder.state, RuntimeTaskState.loginRequired);
    expect(waterRuntime.state.waterOrder.message, contains('请勿关闭 App'));
  });
  test('real washer create persists pending ID before failing detail read',
      () async {
    final transport = _WasherTransport();
    final repo = InMemoryWasherHistoryRepository();
    final runtime = FakeShuiRuntime(
        ujing: UjingHttpAdapter(transport: transport, token: 'token'),
        washerHistory: repo,
        sessions: InMemoryAccountSessionRepository(ujing: _account));
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.scanWasher('qr');
    await runtime.createWasherOrder(washModelId: 1, temperatureId: 1);
    expect(transport.creates, 1);
    expect(transport.details, 1);
    expect(runtime.state.currentWasherOrder!.orderId, 'server-created');
    expect(runtime.state.currentWasherOrder!.status, 'pending');
    expect((await repo.loadCurrentOrder())!.orderId, 'server-created');
    await runtime.payCurrentWasherOrderWithAlipay(false);
    expect(transport.pays, 0);
    await runtime.createWasherOrder(washModelId: 1, temperatureId: 1);
    expect(transport.creates, 1);
  });

  test('concurrent water read 401 cannot discard a successful washer creation',
      () async {
    final adapter = _Adapter()..createGate = Completer<WasherOrderUi>();
    final repo = InMemoryWasherHistoryRepository();
    final runtime = await _runtime(adapter,
        washer: repo,
        water: InMemoryWaterOrderRepository(
            snapshot: WaterOrderSnapshot(
                currentOrder: _water.copyWith(ownerAccountKey: 'account-a'))));
    await runtime.scanWasher('qr');
    final creating =
        runtime.createWasherOrder(washModelId: 1, temperatureId: 1);
    await Future<void>.delayed(Duration.zero);
    adapter.waterError = const UjingException('401', authInvalid: true);
    await runtime.refreshCurrentDrinkingWaterOrder();
    adapter.createGate!.complete(_washer);
    await creating;
    expect((await repo.loadCurrentOrder())!.orderId, 'wash-1');
    expect(runtime.state.currentWasherOrder!.ownerAccountKey, 'account-a');
    expect(runtime.state.washerOrder.state, RuntimeTaskState.loginRequired);
    expect(runtime.ujingMutationCount, 0);
    expect(adapter.starts, 0);
  });

  test(
      'concurrent invalidation preserves successful water creation without follow-up query',
      () async {
    final adapter = _Adapter()
      ..waterCreateGate = Completer<WaterPrepareResult>();
    final repo = InMemoryWaterOrderRepository();
    final runtime = await _runtime(adapter, water: repo);
    final creating = runtime.scanDrinkingWaterAndCreateOrder('qr');
    await Future<void>.delayed(Duration.zero);
    await runtime.handleAuthInvalidation(AuthService.ujing,
        expectedEpoch: runtime.ujingAuthEpoch);
    adapter.waterCreateGate!.complete(const WaterPrepareResult(
        ready: WaterReadyUi(
            cd: 'x',
            serviceSubjectId: '',
            serviceSubjectName: '',
            storeId: '',
            balanceFen: 1000),
        order: _water));
    await creating;
    expect((await repo.load())!.currentOrder!.orderId, 'water-1');
    expect(runtime.state.waterOrder.state, RuntimeTaskState.loginRequired);
    expect(adapter.waterQueries, 0);
  });

  test(
      'successful payment and stop survive parallel invalidation without auto-start',
      () async {
    final adapter = _Adapter()..paymentGate = Completer<WasherOrderUi>();
    final repo = InMemoryWasherHistoryRepository(
        currentOrder: _washer.copyWith(ownerAccountKey: 'account-a'));
    final runtime = await _runtime(adapter, washer: repo);
    final payment = runtime.payCurrentWasherOrderWithAlipay(true);
    await Future<void>.delayed(Duration.zero);
    await runtime.handleAuthInvalidation(AuthService.ujing,
        expectedEpoch: runtime.ujingAuthEpoch);
    adapter.paymentGate!.complete(_washer.copyWith(status: '20'));
    await payment;
    expect((await repo.loadCurrentOrder())!.status, '20');
    expect(runtime.state.washerPayment.state, RuntimeTaskState.loginRequired);
    expect(adapter.starts, 0);

    final stopAdapter = _Adapter()..stopGate = Completer<WasherOrderUi>();
    final stopRepo = InMemoryWasherHistoryRepository(
        currentOrder:
            _washer.copyWith(ownerAccountKey: 'account-a', status: '40'));
    final stopRuntime = await _runtime(stopAdapter, washer: stopRepo);
    final stop = stopRuntime.stopCurrentWasherOrder();
    await Future<void>.delayed(Duration.zero);
    await stopRuntime.handleAuthInvalidation(AuthService.ujing,
        expectedEpoch: stopRuntime.ujingAuthEpoch);
    stopAdapter.stopGate!.complete(_washer.copyWith(status: '50'));
    await stop;
    expect(await stopRepo.loadCurrentOrder(), isNull);
    expect((await stopRepo.loadHistory())!.single.status, '50');
    expect(stopRuntime.state.washerOrder.state, RuntimeTaskState.loginRequired);
  });

  test(
      'legacy nonterminal history is processed one candidate at a time before new orders',
      () async {
    final adapter = _Adapter()..washerStatus = '50';
    final repo = InMemoryWasherHistoryRepository(history: const [
      WasherOrderHistoryUi(
          orderId: 'old-a',
          deviceNo: 'a',
          status: '10',
          statusText: '旧订单',
          payPrice: ''),
      WasherOrderHistoryUi(
          orderId: 'old-b',
          deviceNo: 'b',
          status: '40',
          statusText: '旧订单',
          payPrice: ''),
      WasherOrderHistoryUi(
          orderId: 'done',
          deviceNo: 'd',
          status: '50',
          statusText: '完成',
          payPrice: ''),
    ]);
    final runtime = await _runtime(adapter, washer: repo);
    expect(runtime.state.currentWasherOrder!.orderId, 'old-a');
    expect(runtime.state.currentWasherOrder!.status, 'pending');
    await runtime.createWasherOrder(washModelId: 1, temperatureId: 1);
    expect(adapter.washerCreates, 0);
    for (final id in ['old-a', 'old-b']) {
      expect(runtime.state.currentWasherOrder!.orderId, id);
      await runtime.confirmWasherOrderOwner(
          orderId: id, accountKey: 'account-a', epoch: runtime.ujingAuthEpoch);
    }
    expect(runtime.state.currentWasherOrder, isNull);
    expect(runtime.state.washer.history.length, 3);
    expect(
        runtime.state.washer.history
            .where((h) => h.orderId != 'done')
            .every((h) => h.status == '50' && h.ownerAccountKey == 'account-a'),
        true);
    await runtime.scanWasher('qr');
    await runtime.createWasherOrder(washModelId: 1, temperatureId: 1);
    expect(adapter.washerCreates, 1);
  });
  test('damaged storage blocks both replacement creation and legacy adoption',
      () async {
    final adapter = _Adapter();
    final runtime = await _runtime(adapter,
        water: InMemoryWaterOrderRepository(
            snapshot: const WaterOrderSnapshot(currentOrder: _water)),
        washer: InMemoryWasherHistoryRepository(currentOrder: _washer));
    runtime.ujingOrderStorageBlocked = true;
    await runtime.confirmWaterOrderOwner(
        orderId: 'water-1',
        accountKey: 'account-a',
        epoch: runtime.ujingAuthEpoch);
    await runtime.confirmWasherOrderOwner(
        orderId: 'wash-1',
        accountKey: 'account-a',
        epoch: runtime.ujingAuthEpoch);
    await runtime.scanDrinkingWaterAndCreateOrder('new');
    await runtime.scanWasher('new');
    await runtime.createWasherOrder(washModelId: 1, temperatureId: 1);
    expect(
        adapter.waterCreates +
            adapter.washerCreates +
            adapter.waterQueries +
            adapter.washerQueries,
        0);
    expect(runtime.state.currentWaterOrder!.ownerAccountKey, '');
    expect(runtime.state.currentWasherOrder!.ownerAccountKey, '');
  });
  test('damaged codec shapes are rejected, never silently converted to empty',
      () {
    for (final raw in [
      '',
      '[]',
      '{}',
      '{"history":[],"currentOrder":"bad"}',
      '{"history":[42],"currentOrder":null}',
      '{"history":[],"currentOrder":{"orderId":""}}'
    ]) {
      expect(() => WaterOrderCodec.decode(raw), throwsFormatException);
    }
    for (final raw in ['', '{}', '[42]', '[{"orderId":""}]']) {
      expect(() => WasherHistoryCodec.decode(raw), throwsFormatException);
    }
    expect(
        () => WasherHistoryCodec.orderFromMap(
            {'orderId': 'x', 'ownerAccountKey': 42}),
        throwsFormatException);
  });
  test(
      'unknown water owner blocks refresh and replacement until confirmation is saved',
      () async {
    final adapter = _Adapter();
    final repo = InMemoryWaterOrderRepository(
        snapshot: const WaterOrderSnapshot(currentOrder: _water));
    final runtime = await _runtime(adapter, water: repo);
    await runtime.refreshCurrentDrinkingWaterOrder();
    await runtime.scanDrinkingWaterAndCreateOrder('another');
    expect(adapter.waterQueries, 0);
    expect(adapter.waterCreates, 0);
    await runtime.confirmWaterOrderOwner(
        orderId: 'water-1',
        accountKey: 'account-a',
        epoch: runtime.ujingAuthEpoch);
    expect(adapter.waterQueries, 1);
    expect((await repo.load())!.currentOrder!.ownerAccountKey, 'account-a');
  });

  test('stale confirmation account or epoch never adopts water or washer',
      () async {
    final adapter = _Adapter();
    final runtime = await _runtime(adapter,
        water: InMemoryWaterOrderRepository(
            snapshot: const WaterOrderSnapshot(currentOrder: _water)),
        washer: InMemoryWasherHistoryRepository(currentOrder: _washer));
    final epoch = runtime.ujingAuthEpoch;
    runtime.ujingAuthEpoch++;
    await runtime.confirmWaterOrderOwner(
        orderId: 'water-1', accountKey: 'account-a', epoch: epoch);
    await runtime.confirmWasherOrderOwner(
        orderId: 'wash-1', accountKey: 'account-a', epoch: epoch);
    expect(runtime.state.currentWaterOrder!.ownerAccountKey, '');
    expect(runtime.state.currentWasherOrder!.ownerAccountKey, '');
    expect(adapter.waterQueries + adapter.washerQueries, 0);
  });

  test('owner binding save failure leaves unknown order and performs no query',
      () async {
    final adapter = _Adapter();
    final repo =
        _FailWater(snapshot: const WaterOrderSnapshot(currentOrder: _water));
    final runtime = await _runtime(adapter, water: repo);
    await runtime.confirmWaterOrderOwner(
        orderId: 'water-1',
        accountKey: 'account-a',
        epoch: runtime.ujingAuthEpoch);
    expect(runtime.state.currentWaterOrder!.ownerAccountKey, '');
    expect(adapter.waterQueries, 0);
    expect(runtime.ujingMutationCount, 0);
  });

  test('other-account activity prevents query, payment, and replacement',
      () async {
    final adapter = _Adapter();
    final runtime = await _runtime(adapter,
        water: InMemoryWaterOrderRepository(
            snapshot: WaterOrderSnapshot(
                currentOrder: _water.copyWith(ownerAccountKey: 'other'))),
        washer: InMemoryWasherHistoryRepository(
            currentOrder: _washer.copyWith(ownerAccountKey: 'other')));
    await runtime.refreshCurrentDrinkingWaterOrder();
    await runtime.scanDrinkingWaterAndCreateOrder('new');
    await runtime.refreshCurrentWasherOrder();
    await runtime.payCurrentWasherOrderWithAlipay(false);
    await runtime.createWasherOrder(washModelId: 1, temperatureId: 1);
    expect(
        adapter.waterQueries +
            adapter.washerQueries +
            adapter.waterCreates +
            adapter.washerCreates +
            adapter.pays,
        0);
  });

  test(
      'washer owner binding persists activity but never adopts unknown history',
      () async {
    final adapter = _Adapter();
    final repo =
        InMemoryWasherHistoryRepository(currentOrder: _washer, history: const [
      WasherOrderHistoryUi(
          orderId: 'legacy-history',
          deviceNo: '',
          status: '50',
          statusText: '',
          payPrice: '')
    ]);
    final runtime = await _runtime(adapter, washer: repo);
    await runtime.confirmWasherOrderOwner(
        orderId: 'wash-1',
        accountKey: 'account-a',
        epoch: runtime.ujingAuthEpoch);
    expect((await repo.loadCurrentOrder())!.ownerAccountKey, 'account-a');
    expect(runtime.state.washer.history.last.ownerAccountKey, '');
    expect(adapter.pays, 0);
    expect(adapter.starts, 0);
  });

  test(
      'all nonterminal washer statuses refresh and persist including 10 20 21 40',
      () async {
    final adapter = _Adapter();
    final repo = InMemoryWasherHistoryRepository(
        currentOrder: _washer.copyWith(ownerAccountKey: 'account-a'));
    final runtime = await _runtime(adapter, washer: repo);
    for (final status in ['10', '20', '21', '40']) {
      adapter.washerStatus = status;
      await runtime.refreshCurrentWasherOrder();
      expect(runtime.state.currentWasherOrder!.status, status);
      expect((await repo.loadCurrentOrder())!.status, status);
    }
    runtime.resetWasherTransient();
    expect(runtime.state.currentWasherOrder!.orderId, 'wash-1');
    final restored = await _runtime(_Adapter(), washer: repo);
    expect(restored.state.currentWasherOrder!.status, '40');
  });

  test('terminal washer save failure retains active slot and retries safely',
      () async {
    final adapter = _Adapter()..washerStatus = '50';
    final repo = _FailWasher(
        currentOrder: _washer.copyWith(ownerAccountKey: 'account-a'));
    final runtime = await _runtime(adapter, washer: repo);
    await runtime.refreshCurrentWasherOrder();
    expect(runtime.state.currentWasherOrder!.orderId, 'wash-1');
    expect(runtime.state.washerOrder.state, RuntimeTaskState.failure);
    repo.fail = false;
    await runtime.refreshCurrentWasherOrder();
    expect(runtime.state.currentWasherOrder, isNull);
    expect((await repo.loadHistory())!.single.status, '50');
  });

  test('washer new order is retained on save failure and prevents duplicate',
      () async {
    final adapter = _Adapter();
    final repo = _FailWasher();
    final runtime = await _runtime(adapter, washer: repo);
    await runtime.scanWasher('qr');
    await runtime.createWasherOrder(washModelId: 1, temperatureId: 1);
    await runtime.createWasherOrder(washModelId: 1, temperatureId: 1);
    expect(adapter.washerCreates, 1);
    expect(runtime.state.currentWasherOrder!.ownerAccountKey, 'account-a');
  });

  test(
      'payment blocks duplicate creation and refresh; leave preserves pending payment',
      () async {
    final adapter = _Adapter()..paymentGate = Completer<WasherOrderUi>();
    final runtime = await _runtime(adapter,
        washer: InMemoryWasherHistoryRepository(
            currentOrder: _washer.copyWith(ownerAccountKey: 'account-a')));
    final paying = runtime.payCurrentWasherOrderWithAlipay(false);
    await Future<void>.delayed(Duration.zero);
    expect(runtime.ujingMutationCount, 1);
    runtime.resetWasherTransient();
    expect(runtime.state.washerPayment.isBusy, true);
    await runtime.createWasherOrder(washModelId: 1, temperatureId: 1);
    await runtime.refreshCurrentWasherOrder();
    expect(adapter.washerCreates + adapter.washerQueries, 0);
    adapter.paymentGate!.complete(_washer.copyWith(status: '20'));
    await paying;
    expect(runtime.state.currentWasherOrder!.status, '20');
    expect(runtime.ujingMutationCount, 0);
  });

  test('late washer result and auth error cannot modify another login epoch',
      () async {
    for (final fail in [false, true]) {
      final adapter = _Adapter()..washerGate = Completer<WasherOrderUi>();
      final runtime = await _runtime(adapter,
          washer: InMemoryWasherHistoryRepository(
              currentOrder: _washer.copyWith(ownerAccountKey: 'account-a')));
      final query = runtime.refreshCurrentWasherOrder();
      runtime.ujingAuthEpoch++;
      if (fail) {
        adapter.washerGate!
            .completeError(const UjingException('expired', authInvalid: true));
      } else {
        adapter.washerGate!.complete(_washer.copyWith(status: '50'));
      }
      await query;
      expect(runtime.state.currentWasherOrder!.status, '10');
      expect(runtime.state.ujingAccount!.mobile, 'account-a');
    }
  });

  test('washer unknown code or negative completion wording is not terminal',
      () {
    for (final status in ['10', '20', '21', '40', '99', '']) {
      expect(
          _washer.copyWith(status: status, statusText: '未完成、等待取消').isTerminal,
          false);
    }
  });

  test('owner fields survive order and history codecs', () {
    final water = WaterOrderCodec.decode(WaterOrderCodec.encode(
        WaterOrderSnapshot(
            currentOrder: _water.copyWith(ownerAccountKey: 'a'))));
    expect(water.currentOrder!.ownerAccountKey, 'a');
    final washer = WasherHistoryCodec.orderFromMap(
        WasherHistoryCodec.orderToMap(_washer.copyWith(ownerAccountKey: 'b')));
    expect(washer.ownerAccountKey, 'b');
    expect(
        WasherHistoryCodec.decode(WasherHistoryCodec.encode(const [
          WasherOrderHistoryUi(
              orderId: 'h',
              deviceNo: '',
              status: '',
              statusText: '',
              payPrice: '',
              ownerAccountKey: 'c')
        ])).single.ownerAccountKey,
        'c');
  });
}

Future<FakeShuiRuntime> _runtime(_Adapter adapter,
    {WaterOrderRepository? water, WasherHistoryRepository? washer}) async {
  final runtime = FakeShuiRuntime(
      ujing: adapter,
      water: water,
      washerHistory: washer,
      sessions: InMemoryAccountSessionRepository(ujing: _account));
  addTearDown(runtime.dispose);
  await runtime.ready;
  runtime.stopWaterPolling();
  return runtime;
}

class _Adapter extends FakeUjingAdapter {
  int waterQueries = 0,
      waterCreates = 0,
      washerQueries = 0,
      washerCreates = 0,
      pays = 0,
      starts = 0;
  String washerStatus = '10';
  Completer<WasherOrderUi>? washerGate, paymentGate;
  Completer<WasherOrderUi>? createGate, stopGate;
  Completer<WaterPrepareResult>? waterCreateGate;
  UjingException? waterError;
  @override
  Future<WaterPrepareResult> scanAndCreateWaterOrder(String cd) async {
    waterCreates++;
    if (waterCreateGate != null) return waterCreateGate!.future;
    return const WaterPrepareResult(
        ready: WaterReadyUi(
            cd: 'x',
            serviceSubjectId: '',
            serviceSubjectName: '',
            storeId: '',
            balanceFen: 1000),
        order: _water);
  }

  @override
  Future<WaterOrderUi> refreshWaterOrder(WaterOrderUi current) async {
    waterQueries++;
    if (waterError != null) throw waterError!;
    return current;
  }

  @override
  Future<WasherProgramUi> scanWasher(String qrCode) async => _program;
  @override
  Future<WasherOrderUi> createWasherOrder(
      {required WasherProgramUi program,
      required int washModelId,
      required int temperatureId,
      int? detergentGearId,
      int? disinfectantGearId,
      required int orderSeq}) async {
    washerCreates++;
    if (createGate != null) return createGate!.future;
    return _washer;
  }

  @override
  Future<WasherOrderUi> refreshWasherOrder(WasherOrderUi current) async {
    washerQueries++;
    if (washerGate != null) return washerGate!.future;
    return current.copyWith(status: washerStatus);
  }

  @override
  Future<WasherOrderUi> payWasherOrder(WasherOrderUi current) async {
    pays++;
    if (paymentGate != null) return paymentGate!.future;
    return current.copyWith(status: '20');
  }

  @override
  Future<WasherOrderUi> startWasherOrder(
      WasherOrderUi current, int remainSeconds) async {
    starts++;
    return current.copyWith(status: '40');
  }

  @override
  Future<WasherOrderUi> stopWasherOrder(WasherOrderUi current) async {
    if (stopGate != null) return stopGate!.future;
    return current.copyWith(status: '50');
  }
}

class _WasherTransport implements UjingTransport {
  int creates = 0, details = 0, pays = 0;
  @override
  Future<Map<String, dynamic>> send(UjingRequest request) async {
    switch (request.path) {
      case 'devices/scanWasherCode':
        return {
          'result': {
            'deviceId': 'd',
            'deviceTypeId': 1,
            'createOrderEnabled': true
          }
        };
      case 'app/washer/devices/program/info':
        return {'storeId': 's', 'deviceNo': 'device'};
      case 'orders/create':
        creates++;
        return {'orderId': 'server-created'};
      case 'orders/server-created/detail':
        details++;
        throw const UjingException('detail offline');
      case 'payment/arguments':
        pays++;
        return {};
      default:
        throw StateError(request.path);
    }
  }
}

class _FailWater extends InMemoryWaterOrderRepository {
  _FailWater({super.snapshot});
  @override
  Future<void> save(WaterOrderSnapshot snapshot) async =>
      throw StateError('disk');
}

class _FailWasher extends InMemoryWasherHistoryRepository {
  _FailWasher({super.currentOrder});
  bool fail = true;
  @override
  Future<void> saveSnapshot(
      {WasherOrderUi? currentOrder,
      required List<WasherOrderHistoryUi> history}) async {
    if (fail) throw StateError('disk');
    await super.saveSnapshot(currentOrder: currentOrder, history: history);
  }
}
