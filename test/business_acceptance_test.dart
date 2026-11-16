import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'support/test_runtime.dart';
import 'package:flandresy/src/data/account_session_repository.dart';
import 'package:flandresy/src/data/adapters/real_shower798_adapter.dart';
import 'package:flandresy/src/data/adapters/shower798_adapter.dart';
import 'package:flandresy/src/data/adapters/shower798_transport.dart';
import 'package:flandresy/src/data/secure_session_repository.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';

const _a = '13800000001';
const _b = '13800000002';

void main() {
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
        TestRuntime(sessions: sessions, secure: secure, shower798: adapter);
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
        TestRuntime(shower798: RealShower798Adapter(transport: transport));
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
