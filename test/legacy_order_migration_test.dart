import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/account_session_repository.dart';
import 'package:flandresy/src/data/adapters/ujing_http_adapter.dart';
import 'package:flandresy/src/data/adapters/ujing_transport.dart';
import 'package:flandresy/src/data/app_bootstrap.dart';
import 'package:flandresy/src/data/water_order_repository.dart';
import 'package:flandresy/src/data/washer_history_repository.dart';
import 'package:flandresy/src/runtime/fake_shui_runtime.dart';
import 'package:flandresy/src/runtime/shui_runtime_base.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'package:flandresy/src/runtime/models/water_order.dart';
import 'package:flandresy/src/runtime/models/washer_order.dart'
    hide formatFenAmount;

const _account =
    UjingAccountUi(mobile: '13800000001', userId: 'a', serviceSubjectId: 's');
const _water = WaterOrderUi(
    orderId: 'w',
    orderNo: 'w-no',
    serviceSubjectName: '',
    storeName: '',
    deviceNo: 'water',
    orderStatus: '0',
    orderStatusName: '',
    statusRemark: '',
    warmWaterMl: 0,
    waterSeconds: 0,
    payment: 0);
const _history = [
  WasherOrderHistoryUi(
      orderId: 'a',
      deviceNo: 'washer-a',
      status: '10',
      statusText: '',
      payPrice: ''),
  WasherOrderHistoryUi(
      orderId: 'b',
      deviceNo: 'washer-b',
      status: '40',
      statusText: '',
      payPrice: ''),
  WasherOrderHistoryUi(
      orderId: 'done',
      deviceNo: '',
      status: '50',
      statusText: '',
      payPrice: ''),
];

void main() {
  for (final gateWater in [true, false]) {
    test(
        'migration save plus 401 keeps committed A owner in memory and disk (water=$gateWater)',
        () async {
      final water = _GateWater(gate: gateWater);
      final washer = _GateWasher(gate: !gateWater);
      final transport = _Transport();
      final runtime = FakeShuiRuntime(
          water: water,
          washerHistory: washer,
          sessions: InMemoryAccountSessionRepository(ujing: _account),
          ujing: UjingHttpAdapter(transport: transport, token: 'token'));
      addTearDown(runtime.dispose);
      await (gateWater ? water.started.future : washer.started.future);
      await runtime.handleAuthInvalidation(AuthService.ujing,
          expectedEpoch: runtime.ujingAuthEpoch);
      (gateWater ? water.release : washer.release).complete();
      await runtime.ready;
      expect(runtime.state.currentWaterOrder!.ownerAccountKey, _account.mobile);
      expect(
          runtime.state.currentWasherOrder!.ownerAccountKey, _account.mobile);
      expect(
          runtime.state.washer.history
              .every((h) => h.ownerAccountKey == _account.mobile),
          true);
      await runtime.loginUjing('13800000002', '1234');
      expect(runtime.state.currentWaterOrder!.ownerAccountKey, _account.mobile);
      expect(
          runtime.state.currentWasherOrder!.ownerAccountKey, _account.mobile);
      expect(
          (await water.load())!.currentOrder!.ownerAccountKey, _account.mobile);
      expect(
          (await washer.loadHistory())!
              .every((h) => h.ownerAccountKey == _account.mobile),
          true);
      expect(transport.queries, isEmpty);
    });
  }
  for (final preload in [false, true]) {
    for (final token in [false, true]) {
      test(
          'boot preload=$preload credentials=$token assigns before query without treating metadata as login',
          () async {
        final water = InMemoryWaterOrderRepository(
            snapshot: const WaterOrderSnapshot(currentOrder: _water));
        final washer = InMemoryWasherHistoryRepository(history: _history);
        final transport = _Transport()
          ..beforeQuery = () async {
            expect(
                (await water.load())!.currentOrder?.ownerAccountKey ??
                    _account.mobile,
                _account.mobile);
            expect(
                (await washer.loadHistory())!
                    .every((h) => h.ownerAccountKey == _account.mobile),
                true);
          };
        final runtime = await _runtime(transport,
            water: water, washer: washer, preload: preload, token: token);
        await runtime.resumeUjingOrders();
        expect((await water.load())!.currentOrder?.ownerAccountKey,
            _account.mobile);
        expect(
            (await washer.loadHistory())!
                .every((h) => h.ownerAccountKey == _account.mobile),
            true);
        expect(runtime.state.ujingAccount != null, token);
        expect(transport.queries.isEmpty, !token);
        expect(transport.mutations, 0);
      });
    }
  }
  test(
      'completed orders leave activity and all old washer candidates are queried once',
      () async {
    final water = InMemoryWaterOrderRepository(
        snapshot: const WaterOrderSnapshot(currentOrder: _water));
    final washer = InMemoryWasherHistoryRepository(history: _history);
    final transport = _Transport()
      ..waterStatus = '50'
      ..washerStatuses.addAll({'a': '50', 'b': '50'});
    final runtime = await _runtime(transport, water: water, washer: washer);
    await runtime.resumeUjingOrders();
    expect(runtime.state.currentWaterOrder, isNull);
    expect(runtime.state.currentWasherOrder, isNull);
    expect(runtime.state.washer.history.length, 3);
    expect(transport.queries.where((s) => s == 'a').length, 1);
    expect(transport.queries.where((s) => s == 'b').length, 1);
    await runtime.resumeUjingOrders();
    expect(transport.queries.where((s) => s == 'a').length, 1);
    expect(transport.mutations, 0);
  });
  test(
      'nonterminal or failed candidate stays active and does not loop or skip next candidate',
      () async {
    for (final failure in [false, true]) {
      final washer = InMemoryWasherHistoryRepository(history: _history);
      final transport = _Transport()
        ..washerStatuses['a'] = '40'
        ..failOrder = failure ? 'a' : null;
      final runtime = await _runtime(transport, washer: washer);
      await Future<void>.delayed(Duration.zero);
      expect(runtime.state.currentWasherOrder!.orderId, 'a');
      expect(transport.queries.where((s) => s == 'a').length, 1);
      expect(transport.queries.contains('b'), false);
      transport.failOrder = null;
      transport.washerStatuses['a'] = '50';
      transport.washerStatuses['b'] = '50';
      await runtime.resumeUjingOrders();
      expect(runtime.state.currentWasherOrder, isNull);
    }
  });
  test(
      'no account waits for login; login migrates then queries without side effects',
      () async {
    final transport = _Transport();
    final water = InMemoryWaterOrderRepository(
        snapshot: const WaterOrderSnapshot(currentOrder: _water));
    final runtime =
        await _runtime(transport, water: water, account: false, token: false);
    await runtime.resumeUjingOrders();
    expect(runtime.state.currentWaterOrder!.ownerAccountKey, '');
    expect(transport.queries, isEmpty);
    await runtime.loginUjing(_account.mobile, '1234');
    expect(runtime.state.currentWaterOrder!.ownerAccountKey, _account.mobile);
    expect(transport.queries, contains('water'));
    expect(transport.mutations, 0);
  });
  test(
      'missing credentials retain A ownership for all candidates after B login',
      () async {
    final transport = _Transport();
    final washer = InMemoryWasherHistoryRepository(history: _history);
    final water = InMemoryWaterOrderRepository(
        snapshot: const WaterOrderSnapshot(currentOrder: _water));
    final runtime =
        await _runtime(transport, washer: washer, water: water, token: false);
    await runtime.loginUjing('13800000002', '1234');
    expect(runtime.state.currentWaterOrder!.ownerAccountKey, _account.mobile);
    expect(runtime.state.currentWasherOrder!.ownerAccountKey, _account.mobile);
    expect(
        (await washer.loadHistory())!
            .every((h) => h.ownerAccountKey == _account.mobile),
        true);
    expect(transport.queries, isEmpty);
  });
  test(
      'existing owner is never overwritten and ordinary owned history is not promoted',
      () async {
    final transport = _Transport();
    final water = InMemoryWaterOrderRepository(
        snapshot: WaterOrderSnapshot(
            currentOrder: _water.copyWith(ownerAccountKey: 'other')));
    final washer = InMemoryWasherHistoryRepository(history: const [
      WasherOrderHistoryUi(
          orderId: 'ordinary',
          deviceNo: '',
          status: '40',
          statusText: '',
          payPrice: '',
          ownerAccountKey: 'other'),
    ]);
    final runtime = await _runtime(transport, water: water, washer: washer);
    await runtime.resumeUjingOrders();
    expect(runtime.state.currentWaterOrder!.ownerAccountKey, 'other');
    expect(runtime.state.currentWasherOrder, isNull);
    expect(transport.queries, isEmpty);
  });
  test(
      'failed migration preserves raw owner and does not query until retry saves',
      () async {
    final transport = _Transport();
    final water = _FailWater();
    final runtime = await _runtime(transport, water: water);
    await runtime.resumeUjingOrders();
    expect(runtime.state.currentWaterOrder!.ownerAccountKey, '');
    expect((await water.load())!.currentOrder!.ownerAccountKey, '');
    expect(transport.queries, isEmpty);
    water.fail = false;
    await runtime.resumeUjingOrders();
    expect(runtime.state.currentWaterOrder!.ownerAccountKey, _account.mobile);
    expect(transport.queries, ['water']);
  });
  test('candidate recovery marker roundtrips but is removed after resolution',
      () {
    const record = WasherOrderHistoryUi(
        orderId: 'legacy',
        deviceNo: '',
        status: '10',
        statusText: '',
        payPrice: '',
        ownerAccountKey: 'a',
        needsRecovery: true);
    final restored =
        WasherHistoryCodec.decode(WasherHistoryCodec.encode([record]));
    expect(restored.single.needsRecovery, true);
    expect(WasherHistoryCodec.legacyCandidate(restored)!.ownerAccountKey, 'a');
  });
}

Future<FakeShuiRuntime> _runtime(_Transport transport,
    {WaterOrderRepository? water,
    WasherHistoryRepository? washer,
    bool preload = false,
    bool token = true,
    bool account = true}) async {
  final history = await washer?.loadHistory();
  final runtime = FakeShuiRuntime(
    ujing:
        UjingHttpAdapter(transport: transport, token: token ? 'token' : null),
    sessions:
        InMemoryAccountSessionRepository(ujing: account ? _account : null),
    water: water,
    washerHistory: washer,
    initial: preload
        ? PersistedSnapshot(
            bathSystem: BathSystemPreference.none,
            ujing: account ? _account : null,
            currentWaterOrder: (await water?.load())?.currentOrder,
            washerHistory: history,
            currentWasherOrder: await washer?.loadCurrentOrder())
        : null,
  );
  addTearDown(runtime.dispose);
  await runtime.ready;
  return runtime;
}

class _Transport implements UjingTransport {
  final queries = <String>[];
  final washerStatuses = <String, String>{};
  String waterStatus = '0';
  String? failOrder;
  int mutations = 0;
  Future<void> Function()? beforeQuery;
  @override
  Future<Map<String, dynamic>> send(UjingRequest request) async {
    if (request.path == 'login') {
      return {'token': 'token', 'userId': 'u', 'serviceSubjectId': 's'};
    }
    if (request.path == 'water/waterOrderDetail') {
      await beforeQuery?.call();
      queries.add('water');
      return {'orderStatus': waterStatus};
    }
    final match = RegExp(r'^orders/([^/]+)/detail$').firstMatch(request.path);
    if (match != null) {
      await beforeQuery?.call();
      final id = match.group(1)!;
      queries.add(id);
      if (id == failOrder) throw StateError('offline');
      return {'status': washerStatuses[id] ?? '40'};
    }
    mutations++;
    throw StateError('Forbidden side effect ${request.path}');
  }
}

class _FailWater extends InMemoryWaterOrderRepository {
  _FailWater()
      : super(snapshot: const WaterOrderSnapshot(currentOrder: _water));
  bool fail = true;
  @override
  Future<void> save(WaterOrderSnapshot snapshot) async {
    if (fail) throw StateError('disk');
    await super.save(snapshot);
  }
}

class _GateWater extends InMemoryWaterOrderRepository {
  _GateWater({required this.gate})
      : super(snapshot: const WaterOrderSnapshot(currentOrder: _water));
  final bool gate;
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<void> save(WaterOrderSnapshot snapshot) async {
    if (gate && !started.isCompleted) {
      started.complete();
      await release.future;
    }
    await super.save(snapshot);
  }
}

class _GateWasher extends InMemoryWasherHistoryRepository {
  _GateWasher({required this.gate}) : super(history: _history);
  final bool gate;
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<void> saveSnapshot(
      {WasherOrderUi? currentOrder,
      required List<WasherOrderHistoryUi> history}) async {
    if (gate && !started.isCompleted) {
      started.complete();
      await release.future;
    }
    await super.saveSnapshot(currentOrder: currentOrder, history: history);
  }
}
