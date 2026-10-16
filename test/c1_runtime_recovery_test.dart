import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/app_bootstrap.dart';
import 'package:flandresy/src/data/account_session_repository.dart';
import 'package:flandresy/src/data/legacy_data_migration.dart';
import 'package:flandresy/src/data/secure_session_repository.dart';
import 'package:flandresy/src/data/settings_repository.dart';
import 'package:flandresy/src/data/water_order_repository.dart';
import 'package:flandresy/src/data/washer_history_repository.dart';
import 'package:flandresy/src/data/adapters/ujing_http_adapter.dart';
import 'package:flandresy/src/data/adapters/ujing_transport.dart';
import 'package:flandresy/src/runtime/hotwater_state.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'package:flandresy/src/runtime/models/water_order.dart';
import 'package:flandresy/src/runtime/models/washer_order.dart';
import 'support/test_runtime.dart';
import 'support/memory_migration_store.dart';
import 'support/fake_payment_launcher.dart';
import 'support/fake_hotwater_adapter.dart';
import 'package:flandresy/src/data/adapters/hotwater_adapter.dart';

const account =
    UjingAccountUi(mobile: 'account-a', userId: 'a', serviceSubjectId: 's');
const waterOrder = WaterOrderUi(
    orderId: '111',
    orderNo: 'no',
    serviceSubjectName: '',
    storeName: '',
    deviceNo: 'd1',
    orderStatus: '0',
    orderStatusName: '未完成',
    statusRemark: '',
    warmWaterMl: 0,
    waterSeconds: 0,
    payment: 0);
const washerOrder = WasherOrderUi(
    orderId: '222',
    deviceNo: 'w1',
    statusText: '待支付',
    payPrice: '1',
    status: '10');

class DetailTransport implements UjingTransport {
  final requests = <UjingRequest>[];
  Map<String, dynamic> detail = {};
  Completer<Map<String, dynamic>>? gate;
  @override
  Future<Map<String, dynamic>> send(UjingRequest request) async {
    requests.add(request);
    if (request.path == 'login') {
      return {'token': 'new-token', 'mobile': 'account-a', 'userId': 'a'};
    }
    if (gate != null) return gate!.future;
    return detail;
  }
}

void main() {
  for (final preloaded in [false, true]) {
    test(
        'both startup routes preserve unknown orders and old credential without requests ($preloaded)',
        () async {
      final store = MemoryMigrationStore({
        'ujing_mobile': 'account-a',
        'water_order_snapshot_json': WaterOrderCodec.encode(
            const WaterOrderSnapshot(currentOrder: waterOrder))
      });
      final migration = LegacyDataMigration(store);
      final transport = DetailTransport();
      final secure =
          InMemorySecureSessionRepository(ujingToken: 'old-real-token');
      final runtime = TestRuntime(
          migration: migration,
          secure: secure,
          ujing: UjingHttpAdapter(
              launcher: const FakePaymentLauncher(),
              transport: transport,
              token: 'old-real-token'),
          sessions: InMemoryAccountSessionRepository(ujing: account),
          water: InMemoryWaterOrderRepository(
              snapshot: const WaterOrderSnapshot(currentOrder: waterOrder)),
          initial: preloaded
              ? const PersistedSnapshot(
                  bathSystem: BathSystemPreference.none,
                  ujing: account,
                  currentWaterOrder: waterOrder)
              : null);
      addTearDown(runtime.dispose);
      await runtime.ready;
      expect(transport.requests, isEmpty);
      expect(runtime.state.ujingAccount, isNull);
      expect(runtime.state.currentWaterOrder!.ownerAccountKey, isEmpty);
      expect(await secure.loadUjingToken(), 'old-real-token');
      runtime.setPollingPaused(true);
      runtime.setPollingPaused(false);
      await runtime.scanDrinkingWaterAndCreateOrder('qr');
      expect(transport.requests, isEmpty);
      await runtime.loginUjing('account-a', 'code');
      expect(migration.needsLogin('ujing'), isFalse);
      expect(migration.isPending('water', '111'), isTrue);
      expect(transport.requests.map((r) => r.path), ['login']);
      await runtime.refreshCurrentDrinkingWaterOrder();
      expect(runtime.state.currentWaterOrder!.orderId, '111');
      expect(migration.isPending('water', '111'), isTrue);
      expect(transport.requests.last.requireVerifiedEnvelope, isTrue);
      expect(
          transport.requests.every(
              (r) => r.path == 'login' || r.path == 'water/waterOrderDetail'),
          isTrue);
    });
  }

  test(
      'strict water verification requires returned ID and matching account; missing or conflicting evidence retains slot',
      () async {
    final store = MemoryMigrationStore({
      'water_order_snapshot_json': WaterOrderCodec.encode(
          const WaterOrderSnapshot(currentOrder: waterOrder))
    });
    final migration = LegacyDataMigration(store);
    await migration.prepare();
    await migration.confirmLogin('ujing');
    final transport = DetailTransport();
    final runtime = TestRuntime(
        migration: migration,
        ujing: UjingHttpAdapter(
            launcher: const FakePaymentLauncher(),
            transport: transport,
            token: 'new'),
        sessions: InMemoryAccountSessionRepository(ujing: account),
        water: InMemoryWaterOrderRepository(
            snapshot: const WaterOrderSnapshot(currentOrder: waterOrder)));
    addTearDown(runtime.dispose);
    await runtime.ready;
    for (final bad in <Map<String, dynamic>>[
      {},
      {'orderId': '111', 'orderStatus': '50'},
      {'orderId': 'other', 'mobile': 'account-a', 'orderStatus': '50'},
      {'orderId': '111', 'mobile': 'other', 'userId': 'a', 'orderStatus': '50'}
    ]) {
      transport.detail = bad;
      expect(await runtime.verifyLegacyWater(), isFalse);
      expect(runtime.state.currentWaterOrder!.ownerAccountKey, isEmpty);
      expect(migration.isPending('water', '111'), isTrue);
    }
    transport.detail = {
      'orderId': '111',
      'mobile': 'account-a',
      'userId': 'a',
      'orderStatus': '0'
    };
    expect(await runtime.verifyLegacyWater(), isTrue);
    expect(runtime.state.currentWaterOrder!.ownerAccountKey, 'account-a');
    expect(migration.isPending('water', '111'), isFalse);
    expect(transport.requests.every((r) => r.path == 'water/waterOrderDetail'),
        isTrue);
  });

  test(
      'washer cannot pay/start/cancel while pending; returned identity permits only a read',
      () async {
    final store = MemoryMigrationStore({
      'washer_order_snapshot_json': jsonEncode({
        'currentOrder': WasherHistoryCodec.orderToMap(washerOrder),
        'history': []
      })
    });
    final migration = LegacyDataMigration(store);
    await migration.prepare();
    await migration.confirmLogin('ujing');
    final transport = DetailTransport();
    final runtime = TestRuntime(
        migration: migration,
        ujing: UjingHttpAdapter(
            launcher: const FakePaymentLauncher(),
            transport: transport,
            token: 'new'),
        sessions: InMemoryAccountSessionRepository(ujing: account),
        washerHistory:
            InMemoryWasherHistoryRepository(currentOrder: washerOrder));
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.payCurrentWasherOrderWithAlipay(true);
    await runtime.cancelCurrentWasherOrder();
    await runtime.startCurrentWasherOrder();
    expect(transport.requests, isEmpty);
    transport.detail = {'orderId': '222', 'userId': 'a', 'status': '10'};
    expect(await runtime.verifyLegacyWasher(), isTrue);
    expect(transport.requests.single.path, 'orders/222/detail');
    expect(runtime.state.currentWasherOrder!.ownerAccountKey, 'account-a');
  });

  test('late verification after account epoch changes cannot claim an order',
      () async {
    final store = MemoryMigrationStore({
      'water_order_snapshot_json': WaterOrderCodec.encode(
          const WaterOrderSnapshot(currentOrder: waterOrder))
    });
    final migration = LegacyDataMigration(store);
    await migration.prepare();
    await migration.confirmLogin('ujing');
    final transport = DetailTransport()..gate = Completer();
    final runtime = TestRuntime(
        migration: migration,
        ujing: UjingHttpAdapter(
            launcher: const FakePaymentLauncher(),
            transport: transport,
            token: 'new'),
        sessions: InMemoryAccountSessionRepository(ujing: account),
        water: InMemoryWaterOrderRepository(
            snapshot: const WaterOrderSnapshot(currentOrder: waterOrder)));
    addTearDown(runtime.dispose);
    await runtime.ready;
    final checking = runtime.verifyLegacyWater();
    runtime.ujingAuthEpoch++;
    transport.gate!.complete(
        {'orderId': '111', 'mobile': 'account-a', 'orderStatus': '50'});
    expect(await checking, isFalse);
    expect(migration.isPending('water', '111'), isTrue);
    expect(runtime.state.currentWaterOrder!.ownerAccountKey, isEmpty);
  });

  test(
      'failed order save or journal write never releases the pending gate; retry succeeds',
      () async {
    final raw = WaterOrderCodec.encode(
        const WaterOrderSnapshot(currentOrder: waterOrder));
    final store = MemoryMigrationStore({'water_order_snapshot_json': raw});
    final migration = LegacyDataMigration(store);
    await migration.prepare();
    await migration.confirmLogin('ujing');
    final repo = FailingWater(
        snapshot: const WaterOrderSnapshot(currentOrder: waterOrder));
    final transport = DetailTransport()
      ..detail = {'orderId': '111', 'mobile': 'account-a', 'orderStatus': '0'};
    final runtime = TestRuntime(
        migration: migration,
        ujing: UjingHttpAdapter(
            launcher: const FakePaymentLauncher(),
            transport: transport,
            token: 'new'),
        sessions: InMemoryAccountSessionRepository(ujing: account),
        water: repo);
    addTearDown(runtime.dispose);
    await runtime.ready;
    repo.fail = true;
    expect(await runtime.verifyLegacyWater(), isFalse);
    expect(migration.isPending('water', '111'), isTrue);
    expect((await repo.load())!.currentOrder!.ownerAccountKey, isEmpty);
    repo.fail = false;
    store.failKey = LegacyDataMigration.journalKey;
    expect(await runtime.verifyLegacyWater(), isFalse);
    expect(migration.blocked, isTrue);
    store.failKey = null;
    await migration.prepare();
    expect(migration.isPending('water', '111'), isTrue);
    expect(await runtime.verifyLegacyWater(), isTrue);
    expect(
        jsonDecode(store.values[LegacyDataMigration.backupKey]!)['values']
            ['water_order_snapshot_json'],
        raw);
  });

  test(
      'all old active washer history keeps a recovery slot; simulated history never resumes',
      () async {
    const history = [
      WasherOrderHistoryUi(
          orderId: 'simulated-old',
          deviceNo: 's',
          status: '40',
          statusText: '运行',
          payPrice: '1',
          ownerAccountKey: '__simulated__',
          needsRecovery: true),
      WasherOrderHistoryUi(
          orderId: 'unknown-old',
          deviceNo: 'u',
          status: '40',
          statusText: '运行',
          payPrice: '2',
          ownerAccountKey: 'account-a'),
    ];
    final store = MemoryMigrationStore(
        {'washer_history_json': WasherHistoryCodec.encode(history)});
    final runtime = TestRuntime(
        migration: LegacyDataMigration(store),
        washerHistory: InMemoryWasherHistoryRepository(history: history));
    addTearDown(runtime.dispose);
    await runtime.ready;
    expect(runtime.state.currentWasherOrder!.orderId, 'unknown-old');
    expect(runtime.migration.isPending('washer', 'unknown-old'), isTrue);
    expect(runtime.state.washer.history.first.needsRecovery, isFalse);
    expect(runtime.migration.preservedHistory.length, 2);
  });

  test(
      'old hotwater needs real identity step and original device/isn before explicit stop; never restarts',
      () async {
    const session = HotwaterSession(
        id: 'original-session',
        account: 'account-a',
        system: BathSystemPreference.zhuli,
        simulated: false,
        deviceId: 'old-device',
        startedAtMillis: 1,
        baselineOrderIds: [],
        phase: HotwaterSessionPhase.uncertain);
    final settings = InMemorySettingsRepository();
    await settings.saveHotwaterSession(session);
    final secure = InMemorySecureSessionRepository();
    await secure.saveHotwaterIsn(session.id, 'original-isn');
    final adapter = CountingHotwater();
    final migration = LegacyDataMigration(MemoryMigrationStore(
        {'hotwater_session': jsonEncode(session.toJson())}));
    final runtime = TestRuntime(
        migration: migration,
        settings: settings,
        secure: secure,
        hotwater: adapter,
        sessions: InMemoryAccountSessionRepository(
            zhuli: const ZhuliSession(
                phone: 'account-a', deviceCode: 'wrong-device')));
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.stopActiveHotwater();
    expect(adapter.stops, 0);
    await runtime.loginZhuli('account-a', 'password');
    await runtime.stopActiveHotwater();
    expect(adapter.stops, 0);
    expect(migration.isPending('hotwater', session.id), isTrue);
    await runtime.bindHotwaterDeviceCode('old-device');
    await runtime.stopActiveHotwater();
    expect(adapter.starts, 0);
    expect(adapter.stops, 1);
    expect(adapter.lastIsn, 'original-isn');
    expect(runtime.state.hotwater.session, isNull);
  });

  test(
      'incomplete login response does not confirm old Zhuli identity or erase secure credentials',
      () async {
    const original = ZhuliSessionData(
        platformToken: 'old',
        userId: 'a',
        identityCode: '',
        serverAddr: 'https://example.invalid',
        serverAppId: '',
        serverId: '',
        secretKey: 'old-secret');
    final secure = InMemorySecureSessionRepository(zhuliSession: original);
    final migration =
        LegacyDataMigration(MemoryMigrationStore({'zhuli_phone': 'account-a'}));
    final runtime = TestRuntime(
        migration: migration, secure: secure, hotwater: InvalidLoginHotwater());
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.loginZhuli('account-a', 'password');
    expect(migration.needsLogin('zhuli'), isTrue);
    expect((await secure.loadZhuliSession())!.secretKey, 'old-secret');
  });

  for (final simulated in [false, true]) {
    for (final version in [1, 2]) {
      test(
          'hotwater v$version simulated=$simulated keeps secure isn, unknown expired record is not cleared',
          () async {
        final raw = <String, dynamic>{
          'version': version,
          'id': 'session-old',
          'account': 'account-a',
          'system': 'zhuli',
          'simulated': simulated,
          'deviceId': 'device-old',
          'startedAtMillis': 1,
          'baselineOrderIds': <String>[],
          'phase': 'uncertain',
          'orderId': ''
        };
        final old = HotwaterSession.fromJson(raw);
        final settings = InMemorySettingsRepository();
        await settings.saveHotwaterSession(old);
        final secure = InMemorySecureSessionRepository();
        await secure.saveHotwaterIsn(old.id, 'original-isn');
        final store =
            MemoryMigrationStore({'hotwater_session': jsonEncode(raw)});
        final runtime = TestRuntime(
            migration: LegacyDataMigration(store),
            settings: settings,
            secure: secure);
        addTearDown(runtime.dispose);
        await runtime.ready;
        if (simulated) {
          expect(runtime.state.hotwater.session, isNull);
        } else {
          expect(runtime.state.hotwater.session!.id, old.id);
          expect(await runtime.clearUnreconciledHotwater(), isFalse);
          await runtime.stopActiveHotwater();
          expect(runtime.state.hotwater.session!.id, old.id);
        }
        expect(await secure.loadHotwaterIsn(old.id), 'original-isn');
        expect(store.values[LegacyDataMigration.backupKey],
            isNot(contains('original-isn')));
        expect(
            jsonDecode(store.values[LegacyDataMigration.backupKey]!)['values']
                ['hotwater_session'],
            jsonEncode(raw));
      });
    }
  }
}

class FailingWater extends InMemoryWaterOrderRepository {
  FailingWater({super.snapshot});
  bool fail = false;
  @override
  Future<void> save(WaterOrderSnapshot snapshot) async {
    if (fail) throw StateError('injected save failure');
    await super.save(snapshot);
  }
}

class CountingHotwater extends FakeHotwaterAdapter {
  int starts = 0, stops = 0;
  String? lastIsn;
  @override
  Future<HotwaterActionResult> startHotwater(String deviceId,
      {HotwaterStartProgressCallback? onProgress}) async {
    starts++;
    return super.startHotwater(deviceId, onProgress: onProgress);
  }

  @override
  Future<HotwaterActionResult> stopHotwater(String deviceId,
      {String? isn}) async {
    stops++;
    lastIsn = isn;
    return HotwaterActionResult(deviceId: deviceId, statusText: 'stopped');
  }
}

class InvalidLoginHotwater extends FakeHotwaterAdapter {
  @override
  Future<ZhuliSessionData> loginZhuli(String phone, String password) async =>
      const ZhuliSessionData(
          platformToken: '',
          userId: '',
          identityCode: '',
          serverAddr: '',
          serverAppId: '',
          serverId: '',
          secretKey: '');
}
