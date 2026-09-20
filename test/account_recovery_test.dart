import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/account_session_repository.dart';
import 'package:flandresy/src/data/adapters/ujing_http_adapter.dart';
import 'package:flandresy/src/data/adapters/ujing_transport.dart';
import 'package:flandresy/src/data/app_bootstrap.dart';
import 'package:flandresy/src/data/secure_session_repository.dart';
import 'package:flandresy/src/runtime/fake_shui_runtime.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'package:flandresy/src/runtime/shui_runtime_base.dart';

const _account =
    UjingAccountUi(mobile: '13800000001', userId: 'a', serviceSubjectId: 's');

void main() {
  test('metadata without real token cannot restore login on either boot path',
      () async {
    for (final preload in [false, true]) {
      final runtime = FakeShuiRuntime(
        sessions: InMemoryAccountSessionRepository(ujing: _account),
        initial: preload
            ? const PersistedSnapshot(
                bathSystem: BathSystemPreference.none, ujing: _account)
            : null,
        ujing: UjingHttpAdapter(transport: _Transport()),
      );
      addTearDown(runtime.dispose);
      await runtime.ready;
      expect(runtime.state.ujingAccount, isNull);
      expect(runtime.state.washerLogin.state, RuntimeTaskState.loginRequired);
    }
  });

  test(
      'auth invalidation clears both credentials and ordinary account metadata',
      () async {
    final sessions = InMemoryAccountSessionRepository(ujing: _account);
    final secure = InMemorySecureSessionRepository(ujingToken: 'old');
    final runtime = FakeShuiRuntime(
        sessions: sessions,
        secure: secure,
        ujing: UjingHttpAdapter(transport: _Transport(), token: 'old'));
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.handleAuthInvalidation(AuthService.ujing, expectedEpoch: 0);
    expect(await secure.loadUjingToken(), isNull);
    expect(await sessions.loadUjing(), isNull);
    expect(runtime.state.waterOrder.isBusy, isFalse);
    expect(runtime.state.washer.washerPayment.isBusy, isFalse);
    final restarted = FakeShuiRuntime(
        sessions: sessions,
        secure: secure,
        ujing: UjingHttpAdapter(
            transport: _Transport(), token: await secure.loadUjingToken()));
    addTearDown(restarted.dispose);
    await restarted.ready;
    expect(restarted.state.washerLogin.state, RuntimeTaskState.loginRequired);
  });

  test('old auth error cannot clear newly logged in credentials', () async {
    final transport = _Transport();
    final secure = InMemorySecureSessionRepository();
    final runtime = FakeShuiRuntime(
        secure: secure, ujing: UjingHttpAdapter(transport: transport));
    addTearDown(runtime.dispose);
    await runtime.ready;
    final oldEpoch = runtime.ujingAuthEpoch;
    await runtime.loginUjing('13800000002', '1234');
    await runtime.handleAuthInvalidation(AuthService.ujing,
        expectedEpoch: oldEpoch);
    expect(runtime.state.ujingAccount?.mobile, '13800000002');
    expect(await secure.loadUjingToken(), 'token-13800000002');
  });

  test('account switching rejected during a mutating order action', () async {
    final transport = _Transport();
    final runtime =
        FakeShuiRuntime(ujing: UjingHttpAdapter(transport: transport));
    addTearDown(runtime.dispose);
    await runtime.ready;
    runtime.ujingMutationCount++;
    await runtime.loginUjing('13800000002', '1234');
    expect(transport.logins, 0);
    expect(runtime.state.washerLogin.message, contains('订单操作正在处理'));
    runtime.ujingMutationCount--;
    await runtime.loginUjing('13800000002', '1234');
    expect(transport.logins, 1);
  });

  test('credential cleanup in flight cannot erase a later login', () async {
    final secure = _SlowSecure();
    final transport = _Transport();
    final runtime = FakeShuiRuntime(
        secure: secure, ujing: UjingHttpAdapter(transport: transport));
    addTearDown(runtime.dispose);
    await runtime.ready;
    final cleanup = runtime.handleAuthInvalidation(AuthService.ujing);
    await secure.started.future;
    await runtime.loginUjing('13800000002', '1234');
    expect(transport.logins, 0);
    secure.gate.complete();
    await cleanup;
    await runtime.loginUjing('13800000002', '1234');
    expect(await secure.loadUjingToken(), 'token-13800000002');
  });

  test('login storage failure clears mixed identity and releases auth lock',
      () async {
    final secure = _FailSaveSecure();
    final adapter = UjingHttpAdapter(transport: _Transport());
    final runtime = FakeShuiRuntime(secure: secure, ujing: adapter);
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.loginUjing('13800000002', '1234');
    expect(runtime.state.ujingAccount, isNull);
    expect(adapter.lastToken, isNull);
    expect(runtime.ujingAuthChanging, isFalse);
    expect(runtime.state.washerLogin.state, RuntimeTaskState.failure);
  });
}

class _Transport implements UjingTransport {
  int logins = 0;
  @override
  Future<Map<String, dynamic>> send(UjingRequest request) async {
    if (request.path != 'login') throw StateError('Unexpected ${request.path}');
    logins++;
    final mobile = request.body!['mobile'];
    return {
      'token': 'token-$mobile',
      'mobile': mobile,
      'userId': mobile,
      'serviceSubjectId': 's'
    };
  }
}

class _SlowSecure extends InMemorySecureSessionRepository {
  final gate = Completer<void>();
  final started = Completer<void>();
  @override
  Future<void> clearUjingToken() async {
    if (!started.isCompleted) started.complete();
    await gate.future;
    await super.clearUjingToken();
  }
}

class _FailSaveSecure extends InMemorySecureSessionRepository {
  @override
  Future<void> saveUjingToken(String token) async =>
      throw StateError('disk failure');
}
