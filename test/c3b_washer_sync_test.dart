import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/account_session_repository.dart';
import 'package:flandresy/src/data/secure_session_repository.dart';
import 'package:flandresy/src/data/washer_history_repository.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'package:flandresy/src/runtime/models/washer_order.dart';
import 'package:flandresy/src/washer/washer_payment_card.dart';
import 'package:flandresy/src/runtime/shui_runtime_base.dart';
import 'package:flandresy/src/data/adapters/ujing_adapter.dart';
import 'package:flandresy/src/data/legacy_data_migration.dart';
import 'package:flandresy/src/home/home_screen.dart';
import 'package:flandresy/src/orders/orders_screen.dart';
import 'package:flandresy/src/washer/washer_order_screen.dart';
import 'support/memory_migration_store.dart';
import 'support/fake_ujing_adapter.dart';
import 'support/test_runtime.dart';

const account =
    UjingAccountUi(mobile: 'owner', userId: 'u', serviceSubjectId: 's');
const order = WasherOrderUi(
    orderId: 'order',
    deviceNo: 'device',
    statusText: '启动中',
    payPrice: '3',
    status: '21',
    ownerAccountKey: 'owner');

class ProbeUjing extends FakeUjingAdapter {
  int queries = 0;
  final commands = <String>[];
  String? nextStatus;
  Object? queryError;
  Completer<WasherOrderUi>? queryGate;
  Completer<void>? commandGate;
  @override
  Future<WasherOrderUi> refreshWasherOrder(WasherOrderUi current) async {
    queries++;
    if (queryGate != null) return queryGate!.future;
    if (queryError != null) throw queryError!;
    return current.copyWith(status: nextStatus);
  }

  Future<WasherOrderUi> command(
      String name, WasherOrderUi current, String status) async {
    commands.add(name);
    if (commandGate != null) await commandGate!.future;
    return current.copyWith(status: status);
  }

  @override
  Future<WasherOrderUi> payWasherOrder(WasherOrderUi current) =>
      command('pay', current, '20');
  @override
  Future<WasherOrderUi> startWasherOrder(
          WasherOrderUi current, int remainSeconds) =>
      command('start', current, '21');
  @override
  Future<WasherOrderUi> stopWasherOrder(WasherOrderUi current) =>
      command('stop', current, '50');
  @override
  Future<void> cancelWasherOrder(WasherOrderUi current) async {
    await command('cancel', current, 'cancelled');
  }
}

class SaveProbe extends InMemoryWasherHistoryRepository {
  SaveProbe() : super(currentOrder: order);
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<void> saveSnapshot(
      {WasherOrderUi? currentOrder,
      required List<WasherOrderHistoryUi> history}) async {
    if (gate != null) await gate!.future;
    if (fail) throw StateError('disk');
    await super.saveSnapshot(currentOrder: currentOrder, history: history);
  }
}

TestRuntime runtimeFor(ProbeUjing api,
        {WasherOrderUi? initial = order,
        WasherHistoryRepository? repo,
        LegacyDataMigration? migration}) =>
    TestRuntime(
        ujing: api,
        sessions: InMemoryAccountSessionRepository(ujing: account),
        secure: InMemorySecureSessionRepository(ujingToken: 'test'),
        washerHistory:
            repo ?? InMemoryWasherHistoryRepository(currentOrder: initial),
        migration: migration);
Future<void> settle(TestRuntime runtime) async {
  await runtime.ready;
  await runtime.refreshCurrentWasherOrder();
}

Widget card(WasherOrderUi value) => MaterialApp(
    home: Scaffold(
        body: CurrentWasherOrderPaymentCard(
            order: value,
            paying: false,
            orderBusy: false,
            paymentMessage: null,
            paymentState: const RuntimeActionStatus(),
            onPay: () {},
            onStart: () {},
            onStop: () {},
            onCancel: () {})));

void main() {
  testWidgets('starting order must not offer a nonfunctional stop button',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CurrentWasherOrderPaymentCard(
                order: order,
                paying: false,
                orderBusy: false,
                paymentMessage: null,
                paymentState: const RuntimeActionStatus(),
                onPay: () {},
                onStart: () {},
                onStop: () {},
                onCancel: () {}))));
    expect(find.text('提前停止'), findsNothing);
    expect(find.textContaining('等待设备确认'), findsOneWidget);
  });
  testWidgets('active washer refreshes without opening orders page',
      (tester) async {
    final api = ProbeUjing();
    final runtime = TestRuntime(
        ujing: api,
        sessions: InMemoryAccountSessionRepository(ujing: account),
        secure: InMemorySecureSessionRepository(ujingToken: 'test'),
        washerHistory: InMemoryWasherHistoryRepository(currentOrder: order));
    try {
      await runtime.ready;
      await runtime.refreshCurrentWasherOrder();
      final initial = api.queries;
      await tester.pump(const Duration(seconds: 30));
      expect(api.queries, initial + 1);
    } finally {
      runtime.dispose();
    }
  });
  final matrix = <String, List<String>>{
    '10': ['支付宝支付', '取消订单'],
    '20': ['启动洗衣机', '取消订单'],
    '21': [],
    '40': ['提前停止'],
    '50': [],
    'cancelled': [],
    'pending': [],
    'unexpected': [],
  };
  for (final entry in matrix.entries) {
    testWidgets('button contract ${entry.key}', (tester) async {
      await tester.pumpWidget(card(order.copyWith(status: entry.key)));
      for (final label in ['支付宝支付', '取消订单', '启动洗衣机', '提前停止']) {
        expect(find.text(label),
            entry.value.contains(label) ? findsOneWidget : findsNothing);
      }
    });
  }
  for (final entry
      in {'pay': '10', 'start': '20', 'stop': '40', 'cancel': '20'}.entries) {
    test('runtime supports ${entry.key} only in the allowed state', () async {
      final api = ProbeUjing();
      final runtime =
          runtimeFor(api, initial: order.copyWith(status: entry.value));
      try {
        await settle(runtime);
        switch (entry.key) {
          case 'pay':
            await runtime.payCurrentWasherOrderWithAlipay(false);
          case 'start':
            await runtime.startCurrentWasherOrder();
          case 'stop':
            await runtime.stopCurrentWasherOrder();
          case 'cancel':
            await runtime.cancelCurrentWasherOrder();
        }
        expect(api.commands, [entry.key]);
      } finally {
        runtime.dispose();
      }
    });
  }
  for (final status in ['21', 'pending', 'unexpected']) {
    test('no controls sent for $status; refusal is explained', () async {
      final api = ProbeUjing();
      final runtime = runtimeFor(api, initial: order.copyWith(status: status));
      try {
        await settle(runtime);
        await runtime.payCurrentWasherOrderWithAlipay(false);
        await runtime.startCurrentWasherOrder();
        await runtime.stopCurrentWasherOrder();
        await runtime.cancelCurrentWasherOrder();
        expect(api.commands, isEmpty);
        expect(runtime.state.washerOrder.state, RuntimeTaskState.failure);
        expect(runtime.state.washerOrder.message, isNotEmpty);
      } finally {
        runtime.dispose();
      }
    });
  }
  test('status is rechecked after async entry before sending control',
      () async {
    final api = ProbeUjing();
    final runtime = runtimeFor(api, initial: order.copyWith(status: '20'));
    try {
      await settle(runtime);
      final start = runtime.startCurrentWasherOrder();
      runtime.emit(runtime.state.copyWith(currentWasherOrder: order));
      await start;
      expect(api.commands, isEmpty);
      expect(runtime.state.washerOrder.message, contains('等待设备确认'));
    } finally {
      runtime.dispose();
    }
  });
  testWidgets(
      'background cancels polling; foreground joins one immediate query and restarts timer',
      (tester) async {
    final api = ProbeUjing();
    final runtime = runtimeFor(api);
    try {
      await settle(runtime);
      final before = api.queries;
      runtime.setPollingPaused(true);
      await tester.pump(const Duration(minutes: 2));
      expect(api.queries, before);
      runtime.setPollingPaused(false);
      runtime.setPollingPaused(false);
      await tester.pump();
      expect(api.queries, before + 1);
      await tester.pump(const Duration(seconds: 30));
      expect(api.queries, before + 2);
      runtime.dispose();
      await tester.pump(const Duration(minutes: 2));
      expect(api.queries, before + 2);
    } finally {
      if (!runtime.isDisposed) runtime.dispose();
    }
  });
  testWidgets('startup in background defers washer queries until foreground',
      (tester) async {
    final api = ProbeUjing();
    final runtime = runtimeFor(api);
    try {
      runtime.setPollingPaused(true);
      await runtime.ready;
      await tester.pump(const Duration(minutes: 1));
      expect(api.queries, 0);
      runtime.setPollingPaused(false);
      await tester.pump();
      expect(api.queries, 1);
    } finally {
      runtime.dispose();
    }
  });
  testWidgets(
      'slow automatic query coalesces ticks/manual queries and blocks controls',
      (tester) async {
    final api = ProbeUjing();
    final runtime = runtimeFor(api, initial: order.copyWith(status: '40'));
    try {
      await settle(runtime);
      final before = api.queries;
      final gate = api.queryGate = Completer<WasherOrderUi>();
      await tester.pump(const Duration(seconds: 30));
      final manual = runtime.refreshCurrentWasherOrder();
      await tester.pump(const Duration(seconds: 60));
      await runtime.stopCurrentWasherOrder();
      expect(api.queries, before + 1);
      expect(api.commands, isEmpty);
      gate.complete(order.copyWith(status: '40'));
      await manual;
      api.queryGate = null;
      await tester.pump(const Duration(seconds: 30));
      expect(api.queries, before + 2);
    } finally {
      runtime.dispose();
    }
  });
  testWidgets('automatic ticks never overlap a control request',
      (tester) async {
    final api = ProbeUjing();
    final runtime = runtimeFor(api, initial: order.copyWith(status: '20'));
    try {
      await settle(runtime);
      final before = api.queries;
      final gate = api.commandGate = Completer<void>();
      final start = runtime.startCurrentWasherOrder();
      await tester.pump();
      await tester.pump(const Duration(seconds: 60));
      expect(api.queries, before);
      expect(api.commands, ['start']);
      gate.complete();
      await start;
      await tester.pump(const Duration(seconds: 30));
      expect(api.queries, before + 1);
    } finally {
      runtime.dispose();
    }
  });
  testWidgets(
      'terminal save failure retains slot; successful retry clears home task and stops polling',
      (tester) async {
    final api = ProbeUjing();
    final repo = SaveProbe();
    final runtime = runtimeFor(api, repo: repo);
    try {
      await settle(runtime);
      api.nextStatus = '50';
      repo.fail = true;
      await tester.pump(const Duration(seconds: 30));
      expect(runtime.state.currentWasherOrder, isNotNull);
      expect(
          runtime.state.homeTasks
              .where((t) => t.target == HomeTaskTarget.washer),
          hasLength(1));
      expect(runtime.state.washerOrder.state, RuntimeTaskState.failure);
      repo.fail = false;
      await tester.pump(const Duration(seconds: 30));
      expect(runtime.state.currentWasherOrder, isNull);
      expect(
          runtime.state.homeTasks
              .where((t) => t.target == HomeTaskTarget.washer),
          isEmpty);
      expect((await repo.loadHistory())!.single.status, '50');
      final before = api.queries;
      await tester.pump(const Duration(minutes: 1));
      expect(api.queries, before);
    } finally {
      runtime.dispose();
    }
  });
  testWidgets(
      'unknown response and network failures preserve activity and retry read-only',
      (tester) async {
    final api = ProbeUjing();
    final runtime = runtimeFor(api);
    try {
      await settle(runtime);
      api.nextStatus = 'unexpected';
      await tester.pump(const Duration(seconds: 30));
      expect(runtime.state.currentWasherOrder!.status, 'unexpected');
      api.queryError = const UjingException('结果未确认');
      final before = api.queries;
      await tester.pump(const Duration(seconds: 30));
      expect(runtime.state.currentWasherOrder!.status, 'unexpected');
      expect(runtime.state.washerOrder.state, RuntimeTaskState.failure);
      api.queryError = null;
      api.nextStatus = '40';
      await tester.pump(const Duration(seconds: 30));
      expect(api.queries, before + 2);
      expect(api.commands, isEmpty);
      expect(runtime.state.currentWasherOrder!.status, '40');
    } finally {
      runtime.dispose();
    }
  });
  testWidgets('auth invalidation stops ticks and preserves original order',
      (tester) async {
    final api = ProbeUjing();
    final runtime = runtimeFor(api);
    try {
      await settle(runtime);
      api.queryError = const UjingException('expired', authInvalid: true);
      await tester.pump(const Duration(seconds: 30));
      final before = api.queries;
      expect(runtime.state.washerOrder.state, RuntimeTaskState.loginRequired);
      await tester.pump(const Duration(minutes: 1));
      expect(api.queries, before);
      expect(runtime.state.currentWasherOrder!.orderId, order.orderId);
    } finally {
      runtime.dispose();
    }
  });
  testWidgets('late automatic reply after logout never updates the old order',
      (tester) async {
    final api = ProbeUjing();
    final runtime = runtimeFor(api);
    try {
      await settle(runtime);
      final gate = api.queryGate = Completer<WasherOrderUi>();
      await tester.pump(const Duration(seconds: 30));
      await runtime.handleAuthInvalidation(AuthService.ujing,
          localLogout: true);
      gate.complete(order.copyWith(status: '50'));
      await tester.pump();
      expect(runtime.state.currentWasherOrder!.status, '21');
      final before = api.queries;
      await tester.pump(const Duration(minutes: 1));
      expect(api.queries, before);
    } finally {
      runtime.dispose();
    }
  });
  for (final blocked in ['other-owner', 'C1', 'no-order']) {
    testWidgets('$blocked never starts periodic washer requests',
        (tester) async {
      final api = ProbeUjing();
      final runtime = runtimeFor(api,
          initial: blocked == 'no-order'
              ? null
              : order.copyWith(
                  ownerAccountKey:
                      blocked == 'other-owner' ? 'other' : 'owner'),
          migration: blocked == 'C1'
              ? LegacyDataMigration(
                  MemoryMigrationStore({'use_simulated_backend': false}))
              : null);
      try {
        await runtime.ready;
        await tester.pump(const Duration(minutes: 2));
        runtime.setPollingPaused(true);
        runtime.setPollingPaused(false);
        await tester.pump();
        expect(api.queries, 0);
      } finally {
        runtime.dispose();
      }
    });
  }
  testWidgets('home/details/orders navigation uses one runtime query cadence',
      (tester) async {
    final api = ProbeUjing();
    final runtime = runtimeFor(api);
    void noop() {}
    var page = 'home';
    Widget current() => MaterialApp(
        home: ListenableBuilder(
            listenable: runtime,
            builder: (context, child) {
              if (page == 'home') {
                return HomeScreen(
                    state: runtime.state,
                    onOpenProfile: noop,
                    onOpenDevices: noop,
                    onStartHotwater: noop,
                    onStopHotwater: noop,
                    onScan: noop,
                    onWasherSummary: noop,
                    onSwitchBathSystem: noop,
                    onOpenHotwaterDetail: noop);
              }
              if (page == 'details') {
                return WasherOrderScreen(
                    state: runtime.state,
                    onBack: noop,
                    onCreateOrder: (a, b, c, d) {},
                    onPay: (_) {},
                    onStart: noop,
                    onStop: noop,
                    onCancel: noop,
                    onRefresh: runtime.refreshCurrentWasherOrder);
              }
              return OrdersScreen(
                  state: runtime.state,
                  clock: runtime.clock,
                  onBack: noop,
                  onOpenWasherOrder: noop,
                  onOpenDrinking: noop);
            }));
    try {
      await settle(runtime);
      final before = api.queries;
      for (final target in ['home', 'details', 'orders', 'home']) {
        page = target;
        await tester.pumpWidget(current());
        if (target == 'orders') {
          await tester.tap(find.text('洗衣').first);
          await tester.pump();
        }
        await tester.pump(const Duration(seconds: 30));
      }
      expect(api.queries, before + 4);
      expect(tester.takeException(), isNull);
    } finally {
      runtime.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
  testWidgets(
      'refused payment cannot reuse old success to trigger automatic start',
      (tester) async {
    final api = ProbeUjing();
    final runtime = runtimeFor(api, initial: order.copyWith(status: '20'));
    try {
      await settle(runtime);
      runtime.emit(runtime.state.copyWith(
          currentWasherPayment:
              const WasherPaymentUi(orderId: 'order', paymentSucceeded: true)));
      final payment = runtime.payCurrentWasherOrderWithAlipay(true);
      await tester.pump(const Duration(seconds: 4));
      await payment;
      expect(api.commands, isEmpty);
    } finally {
      runtime.dispose();
    }
  });
  testWidgets(
      'successful payment still honors the existing automatic-start option',
      (tester) async {
    final api = ProbeUjing();
    final runtime = runtimeFor(api, initial: order.copyWith(status: '10'));
    try {
      await settle(runtime);
      final payment = runtime.payCurrentWasherOrderWithAlipay(true);
      await tester.pump();
      expect(api.commands, ['pay']);
      await tester.pump(const Duration(seconds: 3));
      await payment;
      expect(api.commands, ['pay', 'start']);
    } finally {
      runtime.dispose();
    }
  });
  testWidgets('restart restores owned activity and resumes one periodic query',
      (tester) async {
    final repo = SaveProbe();
    final first = runtimeFor(ProbeUjing(), repo: repo);
    await settle(first);
    first.dispose();
    final api = ProbeUjing();
    final runtime = runtimeFor(api, repo: repo);
    try {
      await runtime.ready;
      await tester.pump();
      expect(api.queries, 1);
      await tester.pump(const Duration(seconds: 30));
      expect(api.queries, 2);
      expect(runtime.state.currentWasherOrder!.orderId, 'order');
    } finally {
      runtime.dispose();
    }
  });
  testWidgets(
      'switching account rejects a late reply and suppresses foreign-order polling',
      (tester) async {
    final api = ProbeUjing();
    final runtime = runtimeFor(api);
    try {
      await settle(runtime);
      final gate = api.queryGate = Completer<WasherOrderUi>();
      await tester.pump(const Duration(seconds: 30));
      runtime.beginUjingLoginEpoch();
      runtime.emit(runtime.state.copyWith(
          ujingAccount: const UjingAccountUi(
              mobile: 'other', userId: 'b', serviceSubjectId: 's')));
      gate.complete(order.copyWith(status: '50'));
      await tester.pump();
      expect(runtime.state.currentWasherOrder!.status, '21');
      final before = api.queries;
      await tester.pump(const Duration(seconds: 60));
      expect(api.queries, before);
    } finally {
      runtime.dispose();
    }
  });
  testWidgets('starting explanation fits narrow large-text card',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: CurrentWasherOrderPaymentCard(
                    order: order,
                    paying: false,
                    orderBusy: false,
                    paymentMessage: null,
                    paymentState: const RuntimeActionStatus(),
                    onPay: () {},
                    onStart: () {},
                    onStop: () {},
                    onCancel: () {})))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('等待设备确认'), findsOneWidget);
  });
}
