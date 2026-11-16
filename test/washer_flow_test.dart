import 'dart:async';

import 'package:flandresy/src/data/account_session_repository.dart';
import 'package:flandresy/src/data/adapters/ujing_adapter.dart';
import 'package:flandresy/src/data/washer_history_repository.dart';
import 'package:flandresy/src/runtime/actions/washer_actions.dart';
import 'package:flandresy/src/runtime/live_clock.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'package:flandresy/src/runtime/models/washer_order.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_ujing_adapter.dart';
import 'support/test_runtime.dart';

const _a = '13800000001';
const _b = '13800000002';
const _now = 1700000000000;

UjingAccountUi _account(String mobile) =>
    UjingAccountUi(mobile: mobile, userId: 'u-$mobile', serviceSubjectId: 's');

FakeUjingAdapter _api() =>
    FakeUjingAdapter(netDelay: Duration.zero, payDelay: Duration.zero);

class _Clock implements LiveClock {
  int now = _now;
  @override
  int nowMillis() => now;
}

Future<TestRuntime> _runtime(FakeUjingAdapter api,
    {WasherHistoryRepository? repo,
    String account = _a,
    LiveClock clock = const FixedLiveClock(_now)}) async {
  final runtime = TestRuntime(
    ujing: api,
    washerHistory: repo ?? InMemoryWasherHistoryRepository(),
    sessions: InMemoryAccountSessionRepository(ujing: _account(account)),
    clock: clock,
  );
  addTearDown(runtime.dispose);
  await runtime.ready;
  return runtime;
}

Future<void> _createOrder(TestRuntime runtime) async {
  await runtime.scanWasher('washer-qr');
  final model = runtime.state.washerProgram!.models.first;
  await runtime.createWasherOrder(washModelId: model.id, temperatureId: 1);
}

/// 等待未 await 的后续动作（自动启动等）完成。
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void _resume(TestRuntime runtime) {
  runtime.setPollingPaused(true);
  runtime.setPollingPaused(false);
}

void main() {
  setUp(() {
    WasherActions.autoStartDelay = Duration.zero;
    WasherActions.paymentWatchInterval = const Duration(milliseconds: 10);
  });

  test(
      'staying on the Alipay success page with the screen off still starts '
      'the washer without returning to the app', () async {
    final api = _api()..alipayResult = null; // 支付宝停在成功页，不交回结果
    final runtime = await _runtime(api);
    await _createOrder(runtime);

    runtime.setPollingPaused(true); // 跳到支付宝，本 App 进入后台
    unawaited(runtime.payCurrentWasherOrderWithAlipay(true));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(runtime.state.currentWasherOrder!.status, WasherStatus.running);
    expect(api.startCalls, 1);
    expect(runtime.pollingPaused, isTrue); // 全程没有回到 App
  });

  test('background follow-up stops after the payment window', () async {
    final clock = _Clock();
    final api = _api()
      ..alipayResult = null
      ..payMarksOrderPaid = false;
    final runtime = await _runtime(api, clock: clock);
    await _createOrder(runtime);
    runtime.setPollingPaused(true);
    unawaited(runtime.payCurrentWasherOrderWithAlipay(true));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    clock.now += WasherActions.paymentWatchWindow.inMilliseconds + 1;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // 超出窗口后才到账：后台不再查询，回到 App 时才会确认并启动。
    api.setServerStatus(runtime.state.currentWasherOrder!.orderId, '20',
        text: '已预约');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(api.startCalls, 0);

    runtime.setPollingPaused(false);
    await _settle();
    expect(api.startCalls, 1);
  });

  test('without auto start nothing is queried in the background', () async {
    final api = _api()..alipayResult = null;
    final runtime = await _runtime(api);
    await _createOrder(runtime);
    runtime.setPollingPaused(true);
    unawaited(runtime.payCurrentWasherOrderWithAlipay(false));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(runtime.state.currentWasherOrder!.status, WasherStatus.unpaid);
    expect(api.startCalls, 0);
  });

  test(
      'paying with auto start keeps checking in the background until the '
      'washer starts', () async {
    final api = _api()..alipayResult = null;
    final runtime = await _runtime(api);
    await _createOrder(runtime);
    runtime.setPollingPaused(true);
    unawaited(runtime.payCurrentWasherOrderWithAlipay(true));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(runtime.state.currentWasherOrder!.status, WasherStatus.running);
  });

  test('create, pay and auto start in one flow', () async {
    final api = _api();
    final repo = InMemoryWasherHistoryRepository();
    final runtime = await _runtime(api, repo: repo);
    await _createOrder(runtime);
    final created = runtime.state.currentWasherOrder!;
    expect(created.status, WasherStatus.unpaid);
    expect(created.ownerAccountKey, _a);
    expect(created.createdAtMillis, _now);

    await runtime.payCurrentWasherOrderWithAlipay(true);
    await _settle();

    final order = runtime.state.currentWasherOrder!;
    expect(order.status, WasherStatus.running);
    expect(order.autoStart, isFalse);
    expect(api.startCalls, 1);
    expect((await repo.load())!.orders.single.status, WasherStatus.running);
  });

  test(
      'staying on the Alipay page does not lock the order; returning to the app '
      'confirms payment and starts the washer', () async {
    // 只验证「回到 App」这条兜底路径，关闭后台跟进。
    WasherActions.paymentWatchInterval = const Duration(hours: 1);
    final api = _api()..alipayResult = null; // 支付宝一直不把结果交回
    final runtime = await _runtime(api);
    await _createOrder(runtime);

    final pay = runtime.payCurrentWasherOrderWithAlipay(true);
    await _settle();
    expect(runtime.state.washerPayment.isBusy, isTrue);

    _resume(runtime); // 用户切回 App
    await _settle();
    expect(runtime.state.currentWasherOrder!.status, WasherStatus.running);
    expect(runtime.state.washerPayment.isBusy, isFalse);
    expect(api.startCalls, 1);

    // 支付宝很久以后才返回，不会再次启动。
    api.pendingAlipay!.complete('9000');
    await pay;
    await _settle();
    expect(api.startCalls, 1);
  });

  test('payment confirmed after the app was killed still auto starts once',
      () async {
    // 只验证「重新打开 App」这条兜底路径，关闭后台跟进。
    WasherActions.paymentWatchInterval = const Duration(hours: 1);
    final api = _api()..alipayResult = null;
    final repo = InMemoryWasherHistoryRepository();
    final first = TestRuntime(
      ujing: api,
      washerHistory: repo,
      sessions: InMemoryAccountSessionRepository(ujing: _account(_a)),
      clock: const FixedLiveClock(_now),
    );
    await first.ready;
    await _createOrder(first);
    unawaited(first.payCurrentWasherOrderWithAlipay(true));
    await _settle();
    first.dispose(); // App 被系统杀掉，支付宝结果永远没交回

    expect((await repo.load())!.orders.single.autoStart, isTrue);
    final restored = await _runtime(api, repo: repo);
    await _settle();
    expect(restored.state.currentWasherOrder!.status, WasherStatus.running);
    expect(api.startCalls, 1);
  });

  test('returning unpaid from Alipay releases the pay button', () async {
    final api = _api()
      ..alipayResult = null
      ..payMarksOrderPaid = false;
    final runtime = await _runtime(api);
    await _createOrder(runtime);
    unawaited(runtime.payCurrentWasherOrderWithAlipay(true));
    await _settle();

    _resume(runtime);
    await _settle();
    expect(runtime.state.currentWasherOrder!.status, WasherStatus.unpaid);
    expect(runtime.state.washerPayment.isBusy, isFalse);
    expect(runtime.state.washerPayment.message, contains('重新支付'));
  });

  test('an unknown server status never traps the order', () async {
    final api = _api();
    final runtime = await _runtime(api);
    await _createOrder(runtime);
    await runtime.payCurrentWasherOrderWithAlipay(false);
    final id = runtime.state.currentWasherOrder!.orderId;
    expect(runtime.state.currentWasherOrder!.status, WasherStatus.reserved);

    api.setServerStatus(id, '60', text: '已退款');
    await runtime.refreshCurrentWasherOrder();
    final order = runtime.state.currentWasherOrder!;
    expect(order.isUnknown, isTrue);
    expect(order.statusLabel, '已退款');

    await runtime.createWasherOrder(washModelId: 1, temperatureId: 1);
    expect(runtime.state.washerOrder.message, contains('未结束'));

    await runtime.removeCurrentWasherOrderLocally();
    expect(runtime.state.currentWasherOrder, isNull);
    expect(runtime.state.washerHistory.first.status, WasherStatus.removed);

    await _createOrder(runtime);
    expect(runtime.state.currentWasherOrder!.orderId, isNot(id));
  });

  test('auto start is attempted only once when the start request fails',
      () async {
    final api = _api()..startError = const UjingException('设备离线');
    final runtime = await _runtime(api);
    await _createOrder(runtime);
    await runtime.payCurrentWasherOrderWithAlipay(true);
    await _settle();
    expect(api.startCalls, 1);
    expect(runtime.state.washerOrder.message, '设备离线');
    expect(runtime.state.currentWasherOrder!.autoStart, isFalse);

    await runtime.refreshCurrentWasherOrder();
    await _settle();
    expect(api.startCalls, 1);
    expect(runtime.state.currentWasherOrder!.canStart, isTrue);
  });

  test('orders are kept per account and never block each other', () async {
    final api = _api();
    final runtime = await _runtime(api);
    await _createOrder(runtime);
    final orderA = runtime.state.currentWasherOrder!.orderId;

    await runtime.loginUjing(_b, '1234');
    expect(runtime.state.currentWasherOrder, isNull);
    expect(runtime.state.otherAccountActiveOrders, 1);
    await _createOrder(runtime);
    expect(runtime.state.currentWasherOrder!.ownerAccountKey, _b);
    expect(runtime.state.washer.orders, hasLength(2));

    await runtime.loginUjing(_a, '1234');
    expect(runtime.state.currentWasherOrder!.orderId, orderA);
  });

  test('a late reply after switching account updates its own order', () async {
    final api = _api();
    final runtime = await _runtime(api);
    await _createOrder(runtime);
    final orderA = runtime.state.currentWasherOrder!.orderId;

    final gate = Completer<void>();
    api.refreshGate = gate;
    final refresh = runtime.refreshCurrentWasherOrder();
    await _settle();
    api.refreshGate = null;
    await runtime.loginUjing(_b, '1234');
    api.setServerStatus(orderA, '20', text: '已预约');
    gate.complete();
    await refresh;

    expect(runtime.state.currentWasherOrder, isNull); // B 没有订单
    final stored =
        runtime.state.washer.orders.singleWhere((o) => o.orderId == orderA);
    expect(stored.ownerAccountKey, _a);
    expect(stored.status, WasherStatus.reserved);
  });

  test('a finished order moves to history with its creation time', () async {
    final api = _api();
    final runtime = await _runtime(api);
    await _createOrder(runtime);
    await runtime.payCurrentWasherOrderWithAlipay(true);
    await _settle();
    final id = runtime.state.currentWasherOrder!.orderId;

    api.setServerStatus(id, '50', text: '已完成');
    await runtime.refreshCurrentWasherOrder();
    expect(runtime.state.currentWasherOrder, isNull);
    final history = runtime.state.washerHistory.first;
    expect(history.orderId, id);
    expect(history.status, WasherStatus.finished);
    expect(history.createdAtMillis, _now);
    expect(runtime.state.homeTasks, isEmpty);
  });

  test('an order saved by an older version is adopted by the logged-in account',
      () async {
    final api = _api();
    final repo = InMemoryWasherHistoryRepository(
        snapshot: const WasherSnapshot(orders: [
      WasherOrderUi(
          orderId: 'old',
          deviceNo: 'd',
          statusText: '待支付',
          payPrice: '¥2.10',
          status: '10'),
    ]));
    final runtime = await _runtime(api, repo: repo);
    expect(runtime.state.currentWasherOrder!.orderId, 'old');
    expect(runtime.state.currentWasherOrder!.ownerAccountKey, _a);
    expect((await repo.load())!.orders.single.ownerAccountKey, _a);
  });

  test('rejected actions always explain why', () async {
    final runtime = await _runtime(_api());
    await runtime.refreshCurrentWasherOrder();
    expect(runtime.state.washerOrder.message, '当前没有进行中的洗衣订单');

    await _createOrder(runtime);
    await runtime.startCurrentWasherOrder();
    expect(runtime.state.washerOrder.state, RuntimeTaskState.failure);
    expect(runtime.state.washerOrder.message, contains('不能启动'));
    await runtime.stopCurrentWasherOrder();
    expect(runtime.state.washerOrder.message, contains('洗衣中'));
  });

  test('orders saved without an end time get one on load', () {
    final order = WasherHistoryCodec.orderFromMap({
      'orderId': 'o',
      'status': WasherStatus.running,
      'remainTimeSeconds': 600,
      'refreshedAtMillis': 1000,
    });
    expect(order.endsAtMillis, 1000 + 600 * 1000);
  });
}
