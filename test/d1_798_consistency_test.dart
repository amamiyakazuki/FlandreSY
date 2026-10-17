import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/account_session_repository.dart';
import 'package:flandresy/src/data/adapters/shower798_adapter.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'package:flandresy/src/data/secure_session_repository.dart';
import 'package:flandresy/src/data/legacy_data_migration.dart';
import 'support/memory_migration_store.dart';
import 'package:flandresy/src/runtime/shui_runtime_base.dart';
import 'support/fake_shower798_adapter.dart';
import 'support/test_runtime.dart';

const a = Shower798DeviceUi(id: 'a', name: 'A');
const b = Shower798DeviceUi(id: 'b', name: 'B');
const account = Shower798AccountUi(mobile: 'test-account', uid: 'u', eid: 'e');
const initial =
    Shower798Persisted(account: account, devices: [a], currentDeviceId: 'a');

class Api extends FakeShower798Adapter {
  List<Shower798DeviceUi> devices = [a];
  Completer<List<Shower798DeviceUi>>? loadGate;
  Object? loginError;
  Object? loadError;
  int loads = 0;
  int adds = 0;
  bool exposeAdded = true;
  int idleQueries = 0;
  @override
  Future<bool> isDeviceIdle(String id) async {
    idleQueries++;
    return true;
  }

  @override
  Future<Shower798SessionData> login(String phone, String smsCode) async {
    if (loginError != null) throw loginError!;
    return Shower798SessionData(
        phone: phone, uid: 'u', eid: 'e', token: 'test-token');
  }

  @override
  Future<List<Shower798DeviceUi>> loadDevices() async {
    loads++;
    final gate = loadGate;
    loadGate = null;
    if (gate != null) return gate.future;
    if (loadError != null) throw loadError!;
    return List.of(devices);
  }

  @override
  Future<void> addDevice(String deviceId) async {
    adds++;
    if (exposeAdded) {
      devices = [...devices, Shower798DeviceUi(id: deviceId, name: deviceId)];
    }
  }
}

class Repo extends InMemoryAccountSessionRepository {
  Repo() : super(shower798: initial);
  bool fail = false;
  Completer<void>? saveGate;
  final saving = Completer<void>();
  @override
  Future<void> saveShower798(Shower798Persisted data) async {
    if (!saving.isCompleted) saving.complete();
    final gate = saveGate;
    saveGate = null;
    if (gate != null) await gate.future;
    if (fail) throw StateError('disk full');
    await super.saveShower798(data);
  }
}

Future<TestRuntime> runtime({Api? api, Repo? repo}) async {
  final result = TestRuntime(shower798: api ?? Api(), sessions: repo ?? Repo());
  addTearDown(result.dispose);
  await result.ready;
  return result;
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('unqueried device never defaults to standby', () {
    expect(a.lastStatus, '状态未查询');
  });
  test('login rejection retains the actual reason instead of expiry', () async {
    final r = await runtime(
        api: Api()..loginError = const Shower798Exception('验证码错误'));
    await r.loginShower798('test-account', '1234');
    expect(r.state.shower798Login.message, contains('验证码错误'));
    expect(r.state.shower798Login.message, isNot(contains('登录已失效')));
    expect(r.state.shower798Account, isNull);
  });
  test('slow refresh followed by add cannot overwrite the addition', () async {
    final gate = Completer<List<Shower798DeviceUi>>();
    final api = Api()..loadGate = gate;
    final repo = Repo();
    final r = await runtime(api: api, repo: repo);
    final refresh = r.refreshShower798Devices();
    await tick();
    final add = r.addShower798Device('b');
    await tick();
    // With serialized operations, the server mutation has not started yet.
    final addsBeforeRelease = api.adds;
    gate.complete([a]);
    await Future.wait([refresh, add]);
    expect(addsBeforeRelease, 0);
    expect(r.state.shower798Devices.map((d) => d.id), ['a', 'b']);
    expect((await repo.loadShower798())!.devices.map((d) => d.id), ['a', 'b']);
  });
  test('failed selection save keeps the previously committed selection',
      () async {
    final repo = Repo();
    final api = Api()..devices = [a, b];
    final r = await runtime(api: api, repo: repo);
    await r.refreshShower798Devices();
    repo.fail = true;
    await r.selectShower798Device('b');
    expect(r.state.currentShower798DeviceId, 'a');
    expect((await repo.loadShower798())!.currentDeviceId, 'a');
  });
  test(
      'confirmed list removal clears selection without choosing another device',
      () async {
    final r = await runtime(api: Api()..devices = [b]);
    await r.refreshShower798Devices();
    expect(r.state.currentShower798DeviceId, isEmpty);
  });
  for (final error in [
    const Shower798Exception('网络请求超时'),
    const Shower798Exception('响应格式异常'),
    const Shower798Exception('服务器拒绝', authInvalid: true),
  ]) {
    test('login error category: ${error.message}', () async {
      final r = await runtime(api: Api()..loginError = error);
      await r.loginShower798('new-account', 'code');
      expect(r.state.shower798Account, isNull);
      expect(r.hotwaterAuthChanging, isFalse);
      expect(r.state.shower798Login.message,
          contains(error.authInvalid ? '登录已失效' : error.message));
      expect(r.state.shower798Devices.map((d) => d.id), ['a']);
    });
  }
  test('list failure during login names its stage and clears new credentials',
      () async {
    final secure = InMemorySecureSessionRepository(shower798Token: 'old-token');
    final repo = Repo();
    final r = TestRuntime(
        sessions: repo,
        secure: secure,
        shower798: Api()..loadError = const Shower798Exception('列表响应异常'));
    addTearDown(r.dispose);
    await r.ready;
    await r.loginShower798('new-account', 'code');
    expect(r.state.shower798Login.message, contains('登录后设备列表读取'));
    expect(r.state.shower798Login.message, contains('列表响应异常'));
    expect(r.state.shower798Account, isNull);
    expect(await secure.loadShower798Token(), isNull);
    expect((await repo.loadShower798())!.account.mobile, isEmpty);
  });
  test('login snapshot failure cannot leave mixed identity', () async {
    final repo = Repo()..fail = true;
    final secure = InMemorySecureSessionRepository();
    final r = TestRuntime(sessions: repo, secure: secure, shower798: Api());
    addTearDown(r.dispose);
    await r.ready;
    await r.loginShower798('new-account', 'code');
    expect(r.state.shower798Login.message, contains('登录信息保存'));
    expect(r.state.shower798Account, isNull);
    expect(await secure.loadShower798Token(), isNull);
    expect((await repo.loadShower798())!.account.mobile, isEmpty);
  });
  test('duplicate refreshes share one request and preserve login feedback',
      () async {
    final gate = Completer<List<Shower798DeviceUi>>();
    final api = Api()..loadGate = gate;
    final r = await runtime(api: api);
    final loginMessage = r.state.shower798Login.message;
    final first = r.refreshShower798Devices();
    final second = r.refreshShower798Devices();
    await tick();
    expect(api.loads, 1);
    expect(r.state.shower798DevicesStatus.isBusy, isTrue);
    gate.complete([a, b]);
    await Future.wait([first, second]);
    expect(r.state.shower798Login.message, loginMessage);
    expect(r.state.shower798DevicesStatus.state, RuntimeTaskState.success);
  });
  test('sequential additions and queued selection persist the final list',
      () async {
    final repo = Repo();
    final r = await runtime(repo: repo);
    await Future.wait([
      r.addShower798Device('b'),
      r.addShower798Device('c'),
      r.selectShower798Device('a')
    ]);
    expect(r.state.shower798Devices.map((d) => d.id), ['a', 'b', 'c']);
    expect(r.state.currentShower798DeviceId, 'a');
    expect((await repo.loadShower798())!.devices.length, 3);
  });
  for (final failingStage in ['read', 'save']) {
    test('confirmed add with $failingStage failure retries without resending',
        () async {
      final api = Api();
      final repo = Repo();
      final r = await runtime(api: api, repo: repo);
      if (failingStage == 'read') {
        api.loadError = const Shower798Exception('offline');
      }
      if (failingStage == 'save') repo.fail = true;
      await r.addShower798Device('b');
      expect(api.adds, 1);
      expect(r.state.shower798Devices.map((d) => d.id), ['a']);
      expect(r.state.shower798DevicesStatus.state, RuntimeTaskState.failure);
      expect(r.state.shower798DevicesStatus.message, contains('添加请求已确认'));
      repo.fail = false;
      api.loadError = null;
      await r.addShower798Device('b');
      expect(api.adds, 1);
      expect(r.state.shower798Devices.map((d) => d.id), ['a', 'b']);
      expect((await repo.loadShower798())!.currentDeviceId, 'b');
    });
  }
  test('refresh recovery after partial add only reads the server', () async {
    final repo = Repo();
    final api = Api();
    final r = await runtime(api: api, repo: repo);
    repo.fail = true;
    await r.addShower798Device('b');
    repo.fail = false;
    await r.refreshShower798Devices();
    expect(api.adds, 1);
    expect(r.state.shower798Devices.map((d) => d.id), ['a', 'b']);
    expect(r.state.currentShower798DeviceId, 'a');
  });
  test(
      'save waits for durability before publishing and selection queues behind it',
      () async {
    final gate = Completer<void>();
    final repo = Repo()..saveGate = gate;
    final r = await runtime(api: Api()..devices = [a, b], repo: repo);
    final refreshing = r.refreshShower798Devices();
    await repo.saving.future;
    final selecting = r.selectShower798Device('b');
    expect(r.state.shower798Devices.length, 1);
    expect(r.state.currentShower798DeviceId, 'a');
    gate.complete();
    await Future.wait([refreshing, selecting]);
    expect(r.state.currentShower798DeviceId, 'b');
    expect((await repo.loadShower798())!.currentDeviceId, 'b');
  });
  test(
      'invalidation during save clears identity after late write, never revives it',
      () async {
    final gate = Completer<void>();
    final repo = Repo()..saveGate = gate;
    final r = await runtime(api: Api()..devices = [a, b], repo: repo);
    final refresh = r.refreshShower798Devices();
    await repo.saving.future;
    final clear = r.handleAuthInvalidation(AuthService.shower798);
    await tick();
    expect(r.state.shower798Account, isNull);
    gate.complete();
    await Future.wait([refresh, clear]);
    expect((await repo.loadShower798())!.account.mobile, isEmpty);
    expect(r.state.shower798Account, isNull);
    expect(r.state.shower798Devices.map((d) => d.id), ['a']);
    await r.loginShower798('new-account', 'code');
    expect((await repo.loadShower798())!.account.mobile, 'new-account');
  });
  test('invalidation rejects late response and queued mutation', () async {
    final gate = Completer<List<Shower798DeviceUi>>();
    final api = Api()..loadGate = gate;
    final r = await runtime(api: api);
    final refresh = r.refreshShower798Devices();
    await tick();
    final adding = r.addShower798Device('b');
    await tick();
    await r.handleAuthInvalidation(AuthService.shower798);
    gate.complete([a, b]);
    await Future.wait([refresh, adding]);
    expect(api.adds, 0);
    expect(r.state.shower798Account, isNull);
    expect(r.state.shower798Devices.map((d) => d.id), ['a']);
  });
  test('refresh network failure preserves credentials, list and login feedback',
      () async {
    final r = await runtime(
        api: Api()..loadError = const Shower798Exception('offline'));
    final message = r.state.shower798Login.message;
    await r.refreshShower798Devices();
    expect(r.state.shower798Account?.mobile, account.mobile);
    expect(r.state.shower798Login.message, message);
    expect(r.state.shower798DevicesStatus.message, 'offline');
  });
  test('refresh explicit auth rejection closes login', () async {
    final r = await runtime(
        api: Api()
          ..loadError = const Shower798Exception('401', authInvalid: true));
    await r.refreshShower798Devices();
    expect(r.state.shower798Account, isNull);
    expect(r.state.shower798Login.state, RuntimeTaskState.loginRequired);
  });
  test('missing selected id is rejected without storage mutation', () async {
    final repo = Repo();
    final r = await runtime(repo: repo);
    await r.selectShower798Device('missing');
    expect(r.state.shower798DevicesStatus.state, RuntimeTaskState.failure);
    expect(r.state.currentShower798DeviceId, 'a');
    expect(repo.saving.isCompleted, isFalse);
  });
  test(
      'request confirmation uses same queue and remains distinct from device state',
      () async {
    final api = Api();
    final repo = Repo();
    final r = await runtime(api: api, repo: repo);
    await Future.wait([
      r.refreshShower798Devices(),
      r.recordShower798StopConfirmation('a', account.mobile)
    ]);
    expect(r.state.shower798Devices.single.displayStatus, '停止请求已确认');
    expect(api.adds, 0);
    expect((await repo.loadShower798())!.devices.single.lastStatus, '停止请求已确认');
  });
  test('late response after runtime disposal cannot save or notify', () async {
    final gate = Completer<List<Shower798DeviceUi>>();
    final repo = Repo();
    final r = TestRuntime(shower798: Api()..loadGate = gate, sessions: repo);
    await r.ready;
    final request = r.refreshShower798Devices();
    await tick();
    r.dispose();
    gate.complete([a, b]);
    await request;
    expect(repo.saving.isCompleted, isFalse);
  });

  test('pending server list does not claim addition fully synchronized',
      () async {
    final api = Api()..exposeAdded = false;
    final r = await runtime(api: api);
    await r.addShower798Device('b');
    expect(r.state.shower798DevicesStatus.state, RuntimeTaskState.failure);
    expect(r.state.shower798DevicesStatus.message, contains('尚未包含'));
    await r.addShower798Device('b');
    expect(api.adds, 1);
    expect(r.state.currentShower798DeviceId, 'a');
  });
  test('list operations never issue device state queries', () async {
    final api = Api();
    final r = await runtime(api: api);
    await r.refreshShower798Devices();
    await r.addShower798Device('b');
    await r.selectShower798Device('a');
    expect(api.idleQueries, 0);
  });
  for (final cleanupFails in [false, true]) {
    test(
        'secure save failure closes login; cleanup failure visible=$cleanupFails',
        () async {
      final secure = FailingSecure()..failClear = cleanupFails;
      final r = TestRuntime(shower798: Api(), secure: secure, sessions: Repo());
      addTearDown(r.dispose);
      await r.ready;
      await r.loginShower798('new-account', 'code');
      expect(r.state.shower798Account, isNull);
      expect(r.state.shower798Login.message, contains('登录信息保存'));
      if (cleanupFails) {
        expect(r.state.shower798Login.message, contains('清理未完成'));
      }
      expect(r.hotwaterAuthChanging, isFalse);
    });
  }
  test('migration confirmation failure retains re-login gate and old records',
      () async {
    final store = MemoryMigrationStore({'shower798_mobile': 'legacy'});
    final migration = LegacyDataMigration(store);
    final repo = Repo();
    final secure = InMemorySecureSessionRepository();
    final r = TestRuntime(
        shower798: Api(), migration: migration, sessions: repo, secure: secure);
    addTearDown(r.dispose);
    await r.ready;
    final backup = store.values[LegacyDataMigration.backupKey];
    store.failKey = LegacyDataMigration.journalKey;
    await r.loginShower798('new-account', 'code');
    expect(r.state.shower798Account, isNull);
    expect(migration.needsLogin('shower798'), isTrue);
    expect(r.state.shower798Login.message, contains('旧数据登录确认保存'));
    expect(store.values[LegacyDataMigration.backupKey], backup);
    expect(await secure.loadShower798Token(), isNull);
  });
  test('login and logout do not bypass a pending list operation', () async {
    final gate = Completer<List<Shower798DeviceUi>>();
    final api = Api()..loadGate = gate;
    final r = await runtime(api: api);
    final request = r.refreshShower798Devices();
    await tick();
    await r.loginShower798('other-account', 'code');
    await r.logoutAccount(AccountKind.shower798);
    expect(r.state.shower798Account?.mobile, account.mobile);
    gate.complete([a]);
    await request;
    await r.logoutAccount(AccountKind.shower798);
    expect(r.state.shower798Account, isNull);
  });
}

class FailingSecure extends InMemorySecureSessionRepository {
  bool failClear = false;
  @override
  Future<void> saveShower798Token(String token) async =>
      throw StateError('secure write');
  @override
  Future<void> clearShower798Token() async {
    if (failClear) throw StateError('secure clear');
    await super.clearShower798Token();
  }
}
