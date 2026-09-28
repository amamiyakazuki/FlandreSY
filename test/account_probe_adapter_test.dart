import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/adapters/ujing_adapter.dart';
import 'package:flandresy/src/data/adapters/ujing_http_adapter.dart';
import 'package:flandresy/src/data/adapters/ujing_transport.dart';
import 'package:flandresy/src/data/adapters/hotwater_adapter.dart';
import 'package:flandresy/src/data/adapters/real_zhuli_adapter.dart';
import 'package:flandresy/src/data/adapters/zhuli_transport.dart';
import 'package:flandresy/src/data/adapters/shower798_adapter.dart';
import 'package:flandresy/src/data/adapters/real_shower798_adapter.dart';
import 'package:flandresy/src/data/adapters/shower798_transport.dart';
import 'package:flandresy/src/data/adapters/fake_ujing_adapter.dart';
import 'package:flandresy/src/data/adapters/fake_hotwater_adapter.dart';
import 'package:flandresy/src/data/adapters/fake_shower798_adapter.dart';

const _session = ZhuliSessionData(
    platformToken: 'p',
    userId: 'old',
    identityCode: 'i',
    serverAddr: 'https://example.invalid',
    serverAppId: 'app',
    serverId: 'server',
    secretKey: 'secret');

void main() {
  test('unsupported probe never silently reports success', () async {
    await expectLater(_UnsupportedUjing().checkAccountValidity(),
        throwsA(isA<UnsupportedError>()));
  });
  test('network timeout is preserved, never relabelled unauthorized', () async {
    final error = TimeoutException('network unavailable');
    final u = _UTransport()..error = error;
    final z = _ZTransport()..error = error;
    final s = _STransport()..error = error;
    await expectLater(
        UjingHttpAdapter(transport: u, token: 'old').checkAccountValidity(),
        throwsA(same(error)));
    await expectLater(
        RealZhuliAdapter(transport: z, session: _session)
            .checkAccountValidity(),
        throwsA(same(error)));
    await expectLater(
        RealShower798Adapter(transport: s, token: 'old').checkAccountValidity(),
        throwsA(same(error)));
    expect(
        [u.requests.length, z.requests.length, s.requests.length], [1, 1, 1]);
  });
  test('Ujing probe is credentialed GET only, no campus change or creation',
      () async {
    final transport = _UTransport();
    await UjingHttpAdapter(transport: transport, token: 'old')
        .checkAccountValidity();
    final request = transport.requests.single;
    expect(request.method, 'GET');
    expect(request.path, 'app/water/serviceSubject/currentInfo');
    expect(request.authToken, 'old');
    expect(request.body, isNull);
    expect(request.appCode, 'CA');
  });
  test('Zhuli probe only reads signed history', () async {
    final transport = _ZTransport();
    await RealZhuliAdapter(transport: transport, session: _session)
        .checkAccountValidity();
    final request = transport.requests.single;
    expect(request.url, endsWith('/consume/list_record_by_staffid'));
    expect(request.params['staff_id'], 'old');
    expect(request.signKey, 'secret');
  });
  test('798 probe only reads authenticated master data', () async {
    final transport = _STransport();
    final adapter = RealShower798Adapter(transport: transport, token: 'old');
    await adapter.checkAccountValidity();
    final request = transport.requests.single;
    expect(request.method, 'GET');
    expect(request.path, 'ui/app/master');
    expect(request.token, 'old');
    expect(request.body, isNull);
    expect(adapter.lastToken, 'old');
  });
  for (final invalid in [false, true]) {
    test('Ujing preserves authInvalid=$invalid without guessing business codes',
        () async {
      final error = UjingException(
          invalid ? 'unauthorized' : 'no current campus',
          authInvalid: invalid);
      final transport = _UTransport()..error = error;
      final adapter = UjingHttpAdapter(transport: transport, token: 'old');
      await expectLater(adapter.checkAccountValidity(), throwsA(same(error)));
      expect(adapter.lastToken, 'old');
      expect(transport.requests, hasLength(1));
    });
    test('Zhuli preserves authInvalid=$invalid without clearing session',
        () async {
      final error = HotwaterException('probe failed', authInvalid: invalid);
      final transport = _ZTransport()..error = error;
      final adapter = RealZhuliAdapter(transport: transport, session: _session);
      await expectLater(adapter.checkAccountValidity(), throwsA(same(error)));
      expect(adapter.hasCredentials, isTrue);
      expect(transport.requests, hasLength(1));
    });
    test('798 preserves authInvalid=$invalid without clearing token', () async {
      final error = Shower798Exception('probe failed', authInvalid: invalid);
      final transport = _STransport()..error = error;
      final adapter = RealShower798Adapter(transport: transport, token: 'old');
      await expectLater(adapter.checkAccountValidity(), throwsA(same(error)));
      expect(adapter.lastToken, 'old');
      expect(transport.requests, hasLength(1));
    });
  }
  test('missing credentials never dispatch a probe', () async {
    final u = _UTransport(), z = _ZTransport(), s = _STransport();
    await expectLater(UjingHttpAdapter(transport: u).checkAccountValidity(),
        throwsA(isA<UjingException>()));
    await expectLater(RealZhuliAdapter(transport: z).checkAccountValidity(),
        throwsA(isA<HotwaterException>()));
    await expectLater(RealShower798Adapter(transport: s).checkAccountValidity(),
        throwsA(isA<Shower798Exception>()));
    expect([...u.requests, ...z.requests, ...s.requests], isEmpty);
  });
  test('late Ujing unauthorized probe never clears a new login token',
      () async {
    final transport = _UTransport()..gate = Completer<Map<String, dynamic>>();
    final adapter = UjingHttpAdapter(transport: transport, token: 'old');
    final probe = expectLater(
        adapter.checkAccountValidity(), throwsA(isA<UjingException>()));
    await adapter.login('new', '1234');
    transport.gate!.completeError(
        const UjingException('old unauthorized', authInvalid: true));
    await probe;
    expect(adapter.lastToken, 'new-token');
  });
  test('late 798 missing-account response never clears new login token',
      () async {
    final transport = _STransport()..gate = Completer<Map<String, dynamic>>();
    final adapter = RealShower798Adapter(transport: transport, token: 'old');
    final probe = expectLater(
        adapter.checkAccountValidity(),
        throwsA(isA<Shower798Exception>()
            .having((e) => e.authInvalid, 'authInvalid', true)));
    await adapter.login('new', '1234');
    transport.gate!.complete({'data': {}});
    await probe;
    expect(adapter.lastToken, 'new-token');
  });
  test('late Zhuli probe error preserves newly logged in session', () async {
    final transport = _ZTransport()..gate = Completer<List<dynamic>>();
    final adapter = RealZhuliAdapter(transport: transport, session: _session);
    final probe = expectLater(
        adapter.checkAccountValidity(), throwsA(isA<HotwaterException>()));
    await adapter.loginZhuli('new', 'password');
    transport.gate!.completeError(
        const HotwaterException('old unauthorized', authInvalid: true));
    await probe;
    transport.gate = null;
    await adapter.checkAccountValidity();
    expect(transport.requests.last.params['staff_id'], 'new');
  });
  test('fake probes explicitly succeed without any real service', () async {
    await const FakeUjingAdapter().checkAccountValidity();
    await FakeHotwaterAdapter().checkAccountValidity();
    await FakeShower798Adapter().checkAccountValidity();
  });
}

class _UTransport implements UjingTransport {
  final requests = <UjingRequest>[];
  Object? error;
  Completer<Map<String, dynamic>>? gate;
  @override
  Future<Map<String, dynamic>> send(UjingRequest request) async {
    requests.add(request);
    if (request.path == 'login') {
      return {'token': 'new-token', 'mobile': 'new', 'userId': 'new'};
    }
    expect(request.path, 'app/water/serviceSubject/currentInfo');
    if (error != null) throw error!;
    if (gate != null) return gate!.future;
    return {'balance': 0};
  }
}

class _UnsupportedUjing extends IUjingAdapter {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ZTransport implements ZhuliTransport {
  final requests = <ZhuliRequest>[];
  Object? error;
  Completer<List<dynamic>>? gate;
  @override
  Future<List<dynamic>> getArray(ZhuliRequest request) async {
    requests.add(request);
    if (error != null) throw error!;
    if (gate != null) return gate!.future;
    return [];
  }

  @override
  Future<Map<String, dynamic>> getObject(ZhuliRequest request) async {
    expect(request.url, endsWith('/webapi/users/login'));
    return {
      'platform_token': 'new-p',
      'user_info': {'id': 'new'},
      'server_info': {
        'session_secret': 'new-secret',
        'server_addr': 'https://example.invalid'
      }
    };
  }

  @override
  Future<String> getString(ZhuliRequest request) =>
      throw StateError('Unexpected write endpoint');
}

class _STransport implements Shower798Transport {
  final requests = <Shower798Request>[];
  Object? error;
  Completer<Map<String, dynamic>>? gate;
  @override
  Future<Map<String, dynamic>> send(Shower798Request request) async {
    requests.add(request);
    if (request.path == 'acc/login') {
      return {
        'data': {
          'al': {'token': 'new-token', 'uid': 'new', 'eid': 'e'}
        }
      };
    }
    expect(request.path, 'ui/app/master');
    if (error != null) throw error!;
    if (gate != null) return gate!.future;
    return {
      'data': {'account': {}, 'favos': []}
    };
  }

  @override
  Future<String> getImageBase64(Shower798Request request) =>
      throw StateError('Unexpected captcha');
}
