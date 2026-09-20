import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/adapters/ujing_adapter.dart';
import 'package:flandresy/src/data/adapters/ujing_http_adapter.dart';
import 'package:flandresy/src/data/adapters/ujing_transport.dart';
import 'package:flandresy/src/data/water_order_repository.dart';
import 'package:flandresy/src/runtime/fake_shui_runtime.dart';
import 'package:flandresy/src/runtime/models/water_order.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'package:flandresy/src/data/account_session_repository.dart';

void main() {
  test('restart recovers ID after first detail failure without another create',
      () async {
    final transport = _Transport()..detailError = const UjingException('离线');
    final repo = InMemoryWaterOrderRepository();
    final first = FakeShuiRuntime(
      sessions: _sessions(),
      ujing: UjingHttpAdapter(transport: transport, token: 'test'),
      water: repo,
    );
    await first.ready;
    await first.scanDrinkingWaterAndCreateOrder('device-a');
    first.dispose();
    transport.detailError = null;
    final restored = await _runtime(transport, repo);
    await restored.refreshCurrentDrinkingWaterOrder();
    expect(restored.state.currentWaterOrder?.orderId, '1');
    expect(restored.state.currentWaterOrder?.deviceNo, 'machine-1');
    expect(transport.creates, 1);
  });

  testWidgets(
      'leaving page keeps polling; background pauses and foreground resumes',
      (tester) async {
    final transport = _Transport();
    late FakeShuiRuntime runtime;
    await tester.runAsync(() async {
      runtime = await _runtime(transport);
      await runtime.scanDrinkingWaterAndCreateOrder('device-a');
    });
    // Install timer in fake time, then leave the page.
    runtime.startWaterPolling();
    runtime.resetDrinkingWaterTransient();
    final initial = transport.details;
    await tester.pump(const Duration(seconds: 5));
    expect(transport.details, initial + 1);
    runtime.setPollingPaused(true);
    await tester.pump(const Duration(seconds: 15));
    expect(transport.details, initial + 1);
    runtime.setPollingPaused(false);
    await tester.pump();
    expect(transport.details, initial + 2);
    await tester.pump(const Duration(seconds: 5));
    expect(transport.details, initial + 3);
    runtime.stopWaterPolling();
  });

  test('only confirmed status 50 is terminal, never display text', () {
    for (final code in ['0', '', '40', '99']) {
      for (final text in ['未完成', '等待结束', '取水正常完成']) {
        expect(_order(code: code, text: text).isTerminal, isFalse);
      }
    }
    expect(_order(code: '50', text: '').isTerminal, isTrue);
  });

  test('adapter returns created ID without waiting for details', () async {
    final transport = _Transport();
    final adapter = UjingHttpAdapter(transport: transport, token: 'test');
    final result = await adapter.scanAndCreateWaterOrder('device-a');
    expect(result.order?.orderId, '1');
    expect(result.order?.orderNo, 'number-1');
    expect(result.needsDetailRefresh, isTrue);
    expect(transport.details, 0);
    final restored = WaterOrderCodec.decode(WaterOrderCodec.encode(
      WaterOrderSnapshot(currentOrder: result.order),
    ));
    expect(restored.currentOrder?.orderId, '1');
  });

  test('detail failure retains persisted ID; retry queries it without creating',
      () async {
    final transport = _Transport()
      ..detailError = const UjingException('详情暂不可用');
    final repo = InMemoryWaterOrderRepository();
    final runtime = await _runtime(transport, repo);
    await runtime.scanDrinkingWaterAndCreateOrder('device-a');
    expect(runtime.state.currentWaterOrder?.orderId, '1');
    expect((await repo.load())?.currentOrder?.orderId, '1');
    expect(runtime.state.waterOrder.state, RuntimeTaskState.failure);
    transport.detailError = null;
    await runtime.refreshCurrentDrinkingWaterOrder();
    expect(transport.creates, 1);
    expect(runtime.state.currentWaterOrder?.deviceNo, 'machine-1');
  });

  test(
      'pending or unknown old order prevents creation on same or different code',
      () async {
    final transport = _Transport();
    final runtime = await _runtime(transport);
    await runtime.scanDrinkingWaterAndCreateOrder('device-a');
    for (final code in ['device-a', 'device-b']) {
      transport.status = '99';
      await runtime.scanDrinkingWaterAndCreateOrder(code);
      expect(transport.creates, 1);
      expect(runtime.state.currentWaterOrder?.orderId, '1');
      expect(runtime.state.waterOrder.state, RuntimeTaskState.unavailable);
    }
  });

  test('failed old order query prevents creation and preserves failure',
      () async {
    final transport = _Transport();
    final runtime = await _runtime(transport);
    await runtime.scanDrinkingWaterAndCreateOrder('device-a');
    transport.detailError = const UjingException('离线');
    await runtime.scanDrinkingWaterAndCreateOrder('device-b');
    expect(transport.creates, 1);
    expect(runtime.state.currentWaterOrder?.orderId, '1');
    expect(runtime.state.waterOrder.message, '离线');
  });

  test('completed old order saved before new order is created', () async {
    final transport = _Transport();
    final repo = InMemoryWaterOrderRepository();
    final runtime = await _runtime(transport, repo);
    await runtime.scanDrinkingWaterAndCreateOrder('device-a');
    transport.status = '50';
    transport.beforeCreate = () async {
      expect((await repo.load())?.history.single.orderId, '1');
      expect((await repo.load())?.currentOrder, isNull);
      transport.status = '0';
    };
    await runtime.scanDrinkingWaterAndCreateOrder('device-b');
    expect(transport.creates, 2);
    expect(runtime.state.currentWaterOrder?.orderId, '2');
    expect(runtime.state.waterHistory.single.orderId, '1');
  });

  test('manual poll and duplicate scans join an existing automatic refresh',
      () async {
    final transport = _Transport();
    final runtime = await _runtime(transport);
    await runtime.scanDrinkingWaterAndCreateOrder('device-a');
    final gate = Completer<Map<String, dynamic>>();
    transport.detailGate = gate;
    final automatic = runtime.pollWaterOrderOnce();
    final manual = runtime.refreshCurrentDrinkingWaterOrder();
    final scan = runtime.scanDrinkingWaterAndCreateOrder('device-b');
    await runtime.scanDrinkingWaterAndCreateOrder('device-c');
    runtime.resetDrinkingWaterTransient();
    await Future<void>.delayed(Duration.zero);
    expect(transport.details, 2); // initial detail + shared refresh
    gate.complete({'orderStatus': 0});
    await Future.wait([automatic, manual, scan]);
    expect(transport.creates, 1);
    expect(runtime.state.currentWaterOrder?.orderId, '1');
  });

  test('created order is saved before detail query is allowed', () async {
    final transport = _Transport();
    final repo = _Repository()..saveGate = Completer<void>();
    final runtime = await _runtime(transport, repo);
    final scan = runtime.scanDrinkingWaterAndCreateOrder('device-a');
    await repo.saveStarted.future;
    await runtime.refreshCurrentDrinkingWaterOrder();
    expect(transport.details, 0);
    repo.saveGate!.complete();
    await scan;
    expect(transport.details, 1);
  });

  test('creation save failure keeps ID in memory and releases loading',
      () async {
    final transport = _Transport();
    final repo = _Repository()..failSave = true;
    final runtime = await _runtime(transport, repo);
    await runtime.scanDrinkingWaterAndCreateOrder('device-a');
    expect(runtime.state.currentWaterOrder?.orderId, '1');
    expect(runtime.state.waterOrder.state, RuntimeTaskState.failure);
    expect(transport.details, 0);
    repo.failSave = false;
    await runtime.refreshCurrentDrinkingWaterOrder();
    expect((await repo.load())?.currentOrder?.orderId, '1');
    expect(transport.creates, 1);
  });

  test('completion save failure retains old order and prohibits new creation',
      () async {
    final transport = _Transport();
    final repo = _Repository();
    final runtime = await _runtime(transport, repo);
    await runtime.scanDrinkingWaterAndCreateOrder('device-a');
    transport.status = '50';
    repo.failSave = true;
    await runtime.scanDrinkingWaterAndCreateOrder('device-b');
    expect(transport.creates, 1);
    expect(runtime.state.currentWaterOrder?.orderId, '1');
    expect(runtime.state.waterHistory, isEmpty);
    expect(runtime.state.waterOrder.state, RuntimeTaskState.failure);
    repo.failSave = false;
    await runtime.refreshCurrentDrinkingWaterOrder();
    expect(runtime.state.currentWaterOrder, isNull);
    expect(runtime.state.waterHistory.single.orderId, '1');
  });

  test('auth failure retains order and never leaves loading or creates again',
      () async {
    final transport = _Transport();
    final runtime = await _runtime(transport);
    await runtime.scanDrinkingWaterAndCreateOrder('device-a');
    transport.detailError = const UjingException('请重新登录', authInvalid: true);
    await runtime.scanDrinkingWaterAndCreateOrder('device-b');
    expect(transport.creates, 1);
    expect(runtime.state.currentWaterOrder?.orderId, '1');
    expect(runtime.state.waterOrder.state, RuntimeTaskState.loginRequired);
  });
}

Future<FakeShuiRuntime> _runtime(_Transport transport,
    [WaterOrderRepository? repo]) async {
  final runtime = FakeShuiRuntime(
    sessions: _sessions(),
    ujing: UjingHttpAdapter(transport: transport, token: 'test'),
    water: repo,
  );
  addTearDown(runtime.dispose);
  await runtime.ready;
  return runtime;
}

WaterOrderUi _order({String code = '0', String text = ''}) => WaterOrderUi(
      orderId: '1',
      orderNo: 'number-1',
      serviceSubjectName: '',
      storeName: '',
      deviceNo: '',
      orderStatus: code,
      orderStatusName: text,
      statusRemark: text,
      warmWaterMl: 0,
      waterSeconds: 0,
      payment: 0,
    );

InMemoryAccountSessionRepository _sessions() =>
    InMemoryAccountSessionRepository(
      ujing: const UjingAccountUi(
          mobile: '13800000001', userId: 'a', serviceSubjectId: 's'),
    );

class _Transport implements UjingTransport {
  int creates = 0;
  int details = 0;
  String status = '0';
  Object? detailError;
  Completer<Map<String, dynamic>>? detailGate;
  Future<void> Function()? beforeCreate;

  @override
  Future<Map<String, dynamic>> send(UjingRequest request) async {
    switch (request.path) {
      case 'water/serviceSubject/changeWithScan':
        return {
          'newServiceSubjectId': 'subject',
          'newServiceSubjectName': '校区'
        };
      case 'app/water/serviceSubject/currentInfo':
        return {'balance': 1000};
      case 'water/createWaterOrder':
        await beforeCreate?.call();
        creates++;
        return {'orderId': creates, 'orderNo': 'number-$creates'};
      case 'water/waterOrderDetail':
        details++;
        if (detailError != null) throw detailError!;
        if (detailGate != null) return detailGate!.future;
        return {
          'orderStatus': status,
          'deviceNo': 'machine-${request.body!['orderId']}'
        };
      default:
        throw StateError('Unexpected endpoint ${request.path}');
    }
  }
}

class _Repository extends InMemoryWaterOrderRepository {
  bool failSave = false;
  Completer<void>? saveGate;
  final saveStarted = Completer<void>();

  @override
  Future<void> save(WaterOrderSnapshot snapshot) async {
    if (!saveStarted.isCompleted) saveStarted.complete();
    await saveGate?.future;
    if (failSave) throw StateError('storage unavailable');
    await super.save(snapshot);
  }
}
