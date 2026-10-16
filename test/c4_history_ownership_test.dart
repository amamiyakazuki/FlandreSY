import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/adapters/hotwater_adapter.dart';
import 'package:flandresy/src/data/history_repository.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'package:flandresy/src/runtime/models/hotwater_history.dart';

import 'support/fake_hotwater_adapter.dart';
import 'support/test_runtime.dart';

const old = HotwaterHistoryUi(
    time: 'old',
    deviceId: 'old-device',
    amount: '1',
    status: '完成',
    orderId: 'old');
HotwaterHistoryUi record(String id) => HotwaterHistoryUi(
    time: 'today', deviceId: id, amount: '2', status: '完成', orderId: id);

class HistoryAdapter extends FakeHotwaterAdapter {
  Future<List<HotwaterHistoryUi>> Function() loader = () async => [];
  int calls = 0;
  @override
  Future<List<HotwaterHistoryUi>> loadHistory() {
    calls++;
    return loader();
  }

  @override
  Future<ZhuliSessionData> loginZhuli(String phone, String password) async =>
      const ZhuliSessionData(
          platformToken: 'test',
          userId: 'test',
          identityCode: '',
          serverAddr: 'https://example.invalid',
          serverAppId: '',
          serverId: '',
          secretKey: 'test');
}

void main() {
  test(
      'queued B save becomes obsolete before disk write when account switches to C',
      () async {
    final repo = ControlledHistory()..gate = Completer<void>();
    final api = HistoryAdapter()..loader = () async => [record('A')];
    final r = TestRuntime(history: repo, hotwater: api);
    addTearDown(r.dispose);
    await r.ready;
    await login(r, 'A');
    final first = r.loadHotwaterHistory();
    await Future<void>.delayed(Duration.zero);
    await login(r, 'B');
    api.loader = () async => [record('B')];
    final second = r.loadHotwaterHistory();
    await Future<void>.delayed(Duration.zero);
    await login(r, 'C');
    api.loader = () async => [record('C')];
    final third = r.loadHotwaterHistory();
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls, 1);
    repo.gate!.complete();
    await Future.wait([first, second, third]);
    expect(repo.calls, 2);
    expect(
        (await repo.loadHistory())!.map((h) => h.orderId), ['old', 'A', 'C']);
    expect(r.state.currentHotwaterHistory.single.orderId, 'C');
    expect(r.state.hotwater.historyStatus.state, RuntimeTaskState.success);
  });

  test(
      'B failure never displays A; switching back and empty B preserve A and legacy',
      () async {
    final repo = InMemoryHistoryRepository(history: [old]);
    final api = HistoryAdapter()..loader = () async => [record('A')];
    final r = TestRuntime(history: repo, hotwater: api);
    addTearDown(r.dispose);
    await r.ready;
    await login(r, 'A');
    await r.loadHotwaterHistory();
    expect(r.state.currentHotwaterHistory.single.orderId, 'A');
    await r.logoutAccount(AccountKind.zhuli);
    expect(r.state.currentHotwaterHistory, isEmpty);
    await login(r, 'B');
    expect(r.state.hotwater.historyStatus.state, RuntimeTaskState.idle);
    api.loader = () async => throw TimeoutException('offline');
    await r.loadHotwaterHistory();
    expect(r.state.currentHotwaterHistory, isEmpty);
    expect(r.state.hotwater.historyStatus.state, RuntimeTaskState.failure);
    expect(r.state.unassignedHotwaterHistory.single, old);
    api.loader = () async => [];
    await r.loadHotwaterHistory();
    expect(r.state.hotwater.historyStatus.state, RuntimeTaskState.success);
    expect(r.state.hotwaterHistory.map((h) => h.orderId), ['old', 'A']);
    await login(r, 'A');
    expect(r.state.currentHotwaterHistory.single.orderId, 'A');
    // A failed refresh retains A's own cache, never reports a successful update.
    api.loader = () async => throw TimeoutException('offline');
    await r.loadHotwaterHistory();
    expect(r.state.currentHotwaterHistory.single.orderId, 'A');
    expect(r.state.hotwater.historyStatus.message, contains('历史未更新'));
  });

  test(
      'only matching account cache is replaced, including successful empty results',
      () async {
    final repo = InMemoryHistoryRepository(
        history: [old, record('a1').ownedBy('A'), record('b1').ownedBy('B')]);
    final api = HistoryAdapter()
      ..loader = () async => [record('a2').ownedBy('B')];
    final r = TestRuntime(history: repo, hotwater: api);
    addTearDown(r.dispose);
    await r.ready;
    await login(r, 'A');
    await r.loadHotwaterHistory();
    expect(r.state.currentHotwaterHistory.single.orderId, 'a2');
    expect(r.state.currentHotwaterHistory.single.ownerAccount, 'A');
    api.loader = () async => [];
    await r.loadHotwaterHistory();
    expect(r.state.currentHotwaterHistory, isEmpty);
    expect((await repo.loadHistory())!.map((h) => h.orderId), ['old', 'b1']);
  });

  for (final lateError in [false, true]) {
    test('late A network response discarded after B login, error=$lateError',
        () async {
      final gate = Completer<List<HotwaterHistoryUi>>();
      final repo = InMemoryHistoryRepository(history: [old]);
      final api = HistoryAdapter()..loader = () => gate.future;
      final r = TestRuntime(history: repo, hotwater: api);
      addTearDown(r.dispose);
      await r.ready;
      await login(r, 'A');
      final first = r.loadHotwaterHistory();
      await Future<void>.delayed(Duration.zero);
      await login(r, 'B');
      api.loader = () async => [record('B')];
      await r.loadHotwaterHistory();
      if (lateError) {
        gate.completeError(
            const HotwaterException('expired', authInvalid: true));
      } else {
        gate.complete([record('A')]);
      }
      await first;
      expect(r.state.zhuli.phone, 'B');
      expect(r.state.currentHotwaterHistory.single.orderId, 'B');
      expect(r.state.hotwater.historyStatus.state, RuntimeTaskState.success);
      expect((await repo.loadHistory())!.map((h) => h.orderId), ['old', 'B']);
    });
  }

  for (final failFirst in [false, true]) {
    test(
        'slow A save serializes with B and failed queue recovers, fail=$failFirst',
        () async {
      final repo = ControlledHistory()..gate = Completer<void>();
      final gate = repo.gate!;
      final api = HistoryAdapter()..loader = () async => [record('A')];
      final r = TestRuntime(history: repo, hotwater: api);
      addTearDown(r.dispose);
      await r.ready;
      await login(r, 'A');
      final first = r.loadHotwaterHistory();
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls, 1);
      await login(r, 'B');
      api.loader = () async => [record('B')];
      final second = r.loadHotwaterHistory();
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls, 1);
      expect(r.state.currentHotwaterHistory, isEmpty);
      repo.fail = failFirst;
      gate.complete();
      // The first save's failure must not poison the queue; retry B if needed.
      await first;
      await second;
      repo.fail = false;
      await r.loadHotwaterHistory();
      expect(r.state.currentHotwaterHistory.single.orderId, 'B');
      expect(r.state.hotwater.historyStatus.state, RuntimeTaskState.success);
      expect((await repo.loadHistory())!.map((h) => h.orderId),
          failFirst ? ['old', 'B'] : ['old', 'A', 'B']);
    });
  }

  test('save failure keeps state and disk; successful retry commits', () async {
    final repo = ControlledHistory()..fail = true;
    final api = HistoryAdapter()..loader = () async => [record('A')];
    final r = TestRuntime(history: repo, hotwater: api);
    addTearDown(r.dispose);
    await r.ready;
    await login(r, 'A');
    await r.loadHotwaterHistory();
    expect(r.state.hotwaterHistory, [old]);
    expect(await repo.loadHistory(), [old]);
    expect(r.state.hotwater.historyStatus.state, RuntimeTaskState.failure);
    repo.fail = false;
    await r.loadHotwaterHistory();
    expect(r.state.currentHotwaterHistory.single.orderId, 'A');
  });

  test(
      'concurrent same-context calls share network and logout discards response',
      () async {
    final gate = Completer<List<HotwaterHistoryUi>>();
    final api = HistoryAdapter()..loader = () => gate.future;
    final r = TestRuntime(hotwater: api);
    addTearDown(r.dispose);
    await r.ready;
    await login(r, 'A');
    final first = r.loadHotwaterHistory();
    final second = r.loadHotwaterHistory();
    await Future<void>.delayed(Duration.zero);
    expect(api.calls, 1);
    await r.logoutAccount(AccountKind.zhuli);
    gate.complete([record('A')]);
    await Future.wait([first, second]);
    expect(r.state.currentHotwaterHistory, isEmpty);
    expect(r.state.hotwaterHistory, isEmpty);
    expect(r.state.hotwater.historyStatus.isBusy, isFalse);
  });

  test('disposed runtime ignores pending network response', () async {
    final gate = Completer<List<HotwaterHistoryUi>>();
    final repo = InMemoryHistoryRepository(history: [old]);
    final api = HistoryAdapter()..loader = () => gate.future;
    final r = TestRuntime(hotwater: api, history: repo);
    await r.ready;
    await login(r, 'A');
    final request = r.loadHotwaterHistory();
    await Future<void>.delayed(Duration.zero);
    r.dispose();
    gate.complete([record('A')]);
    await request;
    expect(await repo.loadHistory(), [old]);
  });

  test('logged-out request does not query or overwrite legacy records',
      () async {
    final api = HistoryAdapter();
    final r = TestRuntime(
        hotwater: api, history: InMemoryHistoryRepository(history: [old]));
    addTearDown(r.dispose);
    await r.loadHotwaterHistory();
    expect(api.calls, 0);
    expect(
        r.state.hotwater.historyStatus.state, RuntimeTaskState.loginRequired);
    expect(r.state.unassignedHotwaterHistory, [old]);
  });

  test('auth rejection hides current cache but keeps it on disk', () async {
    final repo =
        InMemoryHistoryRepository(history: [record('a1').ownedBy('A'), old]);
    final api = HistoryAdapter()
      ..loader = () async =>
          throw const HotwaterException('expired', authInvalid: true);
    final r = TestRuntime(hotwater: api, history: repo);
    addTearDown(r.dispose);
    await r.ready;
    await login(r, 'A');
    await r.loadHotwaterHistory();
    expect(r.state.zhuli.isLoggedIn, isFalse);
    expect(r.state.currentHotwaterHistory, isEmpty);
    expect(
        r.state.hotwater.historyStatus.state, RuntimeTaskState.loginRequired);
    expect((await repo.loadHistory())!.length, 2);
  });

  test('refresh preserves legacy and other account history on disk', () async {
    final repo = InMemoryHistoryRepository(history: [old]);
    final adapter = HistoryAdapter()..loader = () async => [record('A')];
    final runtime = TestRuntime(history: repo, hotwater: adapter);
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.loginZhuli('A', 'password');
    await Future<void>.delayed(Duration.zero);
    await runtime.loadHotwaterHistory();
    await runtime.logoutAccount(AccountKind.zhuli);
    await runtime.loginZhuli('B', 'password');
    await Future<void>.delayed(Duration.zero);
    adapter.loader = () async => [record('B')];
    await runtime.loadHotwaterHistory();
    expect((await repo.loadHistory())!.map((h) => h.orderId),
        containsAll(['old', 'A', 'B']));
  });
}

Future<void> login(TestRuntime runtime, String account) async {
  await runtime.loginZhuli(account, 'password');
  await Future<void>.delayed(Duration.zero);
  expect(runtime.state.zhuli.phone, account);
}

class ControlledHistory extends InMemoryHistoryRepository {
  ControlledHistory() : super(history: [old]);
  Completer<void>? gate;
  bool fail = false;
  int calls = 0;
  @override
  Future<void> saveHistory(List<HotwaterHistoryUi> history) async {
    calls++;
    await gate?.future;
    if (fail) throw StateError('disk');
    await super.saveHistory(history);
  }
}
