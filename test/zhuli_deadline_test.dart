import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/adapters/io_zhuli_transport.dart';
import 'package:flandresy/src/data/adapters/io_ujing_transport.dart';
import 'package:flandresy/src/data/adapters/io_shower798_transport.dart';
import 'package:flandresy/src/data/adapters/hotwater_adapter.dart';
import 'package:flandresy/src/data/adapters/ujing_adapter.dart';
import 'package:flandresy/src/data/adapters/shower798_adapter.dart';
import 'package:flandresy/src/data/adapters/zhuli_transport.dart';
import 'package:flandresy/src/data/adapters/ujing_transport.dart';
import 'package:flandresy/src/data/adapters/shower798_transport.dart';

const request = ZhuliRequest(
    url: 'https://local.invalid/control',
    params: {'id': 'PRIVATE_DEVICE'},
    signKey: 'PRIVATE_SIGN');
const timeout = Duration(milliseconds: 100);

class Request extends Fake implements HttpClientRequest {
  Request({this.headerDelay = Duration.zero, required this.response});
  final Duration headerDelay;
  final Response response;
  int aborts = 0;
  int sends = 0;
  @override
  final HttpHeaders headers = Headers();
  @override
  Future<HttpClientResponse> close() async {
    sends++;
    await Future<void>.delayed(headerDelay);
    return response;
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    aborts++;
  }
}

class Headers extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  set contentType(ContentType? value) {}
}

class Response extends Stream<List<int>> implements HttpClientResponse {
  Response(
      {this.bodyDelay = Duration.zero,
      this.body = '{"result":true,"data":{"ok":true}}',
      this.statusCode = 200});
  final Duration bodyDelay;
  final String body;
  @override
  final int statusCode;
  @override
  List<Cookie> get cookies => [];
  Stream<List<int>> _body() async* {
    await Future<void>.delayed(bodyDelay);
    yield utf8.encode(body);
  }

  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      _body().listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Client extends Fake implements HttpClient {
  Client(this.requests, {this.connectDelay = Duration.zero});
  final List<Request> requests;
  final Duration connectDelay;
  int calls = 0, closes = 0;
  @override
  Future<HttpClientRequest> getUrl(Uri uri) => openUrl('GET', uri);
  @override
  Future<HttpClientRequest> openUrl(String method, Uri uri) async {
    final req = requests[calls++];
    await Future<void>.delayed(connectDelay);
    return req;
  }

  @override
  void close({bool force = false}) {
    closes++;
  }
}

void main() {
  testWidgets('default Zhuli deadline is fifteen seconds', (tester) async {
    final req =
        Request(response: Response(), headerDelay: const Duration(seconds: 20));
    final client = Client([req]);
    var completed = false;
    final future = IoZhuliTransport(client: client).getObject(request);
    final assertion = expectLater(
        future.whenComplete(() => completed = true),
        throwsA(isA<HotwaterException>()
            .having((e) => e.message, 'message', contains('超时'))));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 14999));
    expect(completed, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    await assertion;
    expect(completed, isTrue);
    expect(req.aborts, 1);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
  });
  for (final phase in ['connection', 'headers', 'body', 'combined']) {
    testWidgets('Zhuli $phase shares one deadline and does not retry',
        (tester) async {
      Duration delay(String name) => phase == 'combined'
          ? const Duration(milliseconds: 40)
          : phase == name
              ? const Duration(milliseconds: 200)
              : Duration.zero;
      final req = Request(
          headerDelay: delay('headers'),
          response: Response(bodyDelay: delay('body')));
      final client = Client([req], connectDelay: delay('connection'));
      final transport =
          IoZhuliTransport(client: client, requestTimeout: timeout);
      final assertion = expectLater(
          transport.getObject(request),
          throwsA(isA<HotwaterException>()
              .having((e) => e.message, 'message', contains('超时'))
              .having((e) => e.authInvalid, 'authInvalid', isFalse)));
      // Advance phase by phase so each individual wait is below the total
      // deadline in the combined case. Old per-phase limits would succeed.
      for (var i = 0; i < 11; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      await assertion;
      expect(req.aborts, 1);
      expect(client.calls, 1);
      expect(client.closes, 0);
      if (phase == 'connection') expect(req.sends, 0);
    });
  }
  testWidgets(
      'a timed out request does not close the client or affect concurrent success',
      (tester) async {
    final slow = Request(
        response: Response(bodyDelay: const Duration(milliseconds: 200)));
    final fast = Request(response: Response());
    final client = Client([slow, fast]);
    final transport = IoZhuliTransport(client: client, requestTimeout: timeout);
    final failed = expectLater(
        transport.getObject(request), throwsA(isA<HotwaterException>()));
    final success = transport.getObject(request);
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(await success, {'ok': true});
    await failed;
    expect(client.calls, 2);
    expect(client.closes, 0);
    expect(slow.aborts, 1);
    expect(fast.aborts, 0);
  });
  for (final status in [401, 403, 500]) {
    testWidgets(
        'Zhuli HTTP $status omits response body and keeps auth classification',
        (tester) async {
      final client = Client([
        Request(
            response: Response(statusCode: status, body: 'PRIVATE_RESPONSE'))
      ]);
      final future = expectLater(
          IoZhuliTransport(client: client).getObject(request),
          throwsA(isA<HotwaterException>()
              .having((e) => e.message, 'message', isNot(contains('PRIVATE')))
              .having((e) => e.code, 'code', '$status')
              .having((e) => e.authInvalid, 'authInvalid',
                  status == 401 || status == 403)));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      await future;
    });
  }
  for (final service in ['zhuli', 'ujing', '798']) {
    for (final response in ['{PRIVATE_BAD_JSON', 'PRIVATE_HTTP_BODY']) {
      testWidgets('$service transport strips $response from exceptions',
          (tester) async {
        final client = Client([
          Request(
              response: Response(
                  body: response,
                  statusCode: response.startsWith('{') ? 200 : 500))
        ]);
        final Future<Object?> operation = switch (service) {
          'zhuli' => IoZhuliTransport(client: client).getObject(request),
          'ujing' => IoUjingTransport(client: client).send(
              const UjingRequest(method: 'GET', path: 'query', appCode: 'CA')),
          _ => IoShower798Transport(client: client)
              .send(const Shower798Request(method: 'GET', path: 'query')),
        };
        final assertion =
            expectLater(operation, throwsA(predicate((Object error) {
          final message = switch (error) {
            HotwaterException e => e.message,
            UjingException e => e.message,
            Shower798Exception e => e.message,
            _ => 'PRIVATE_UNEXPECTED',
          };
          return !message.contains('PRIVATE');
        })));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 1));
        }
        await assertion;
      });
    }
  }
}
