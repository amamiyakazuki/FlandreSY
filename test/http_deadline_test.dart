import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/adapters/http_request_deadline.dart';
import 'package:flandresy/src/data/adapters/io_ujing_transport.dart';
import 'package:flandresy/src/data/adapters/io_shower798_transport.dart';
import 'package:flandresy/src/data/adapters/ujing_adapter.dart';
import 'package:flandresy/src/data/adapters/ujing_transport.dart';
import 'package:flandresy/src/data/adapters/shower798_adapter.dart';
import 'package:flandresy/src/data/adapters/shower798_transport.dart';

void main() {
  test('deadline aborts a connection that arrives after timeout', () async {
    final gate = Completer<HttpClientRequest>();
    final request = _Request();
    final future = HttpRequestDeadline.run(const Duration(milliseconds: 10),
        (deadline) async {
      deadline.attach(await gate.future);
      return true;
    });
    await expectLater(future, throwsA(isA<TimeoutException>()));
    gate.complete(request);
    await Future<void>.delayed(Duration.zero);
    expect(request.aborted, isTrue);
  });

  test('Ujing hung connection has a total deadline and no retry', () async {
    final client = _Client();
    final transport = IoUjingTransport(
        client: client, requestTimeout: const Duration(milliseconds: 10));
    await expectLater(
        transport.send(const UjingRequest(
            method: 'POST', path: 'water/createWaterOrder', appCode: 'CA')),
        throwsA(isA<UjingException>()
            .having((e) => e.message, 'message', contains('超时'))));
    expect(client.calls, 1);
    client.gate.complete(_Request());
    await Future<void>.delayed(Duration.zero);
  });

  test('798 JSON and captcha hung connections time out without retries',
      () async {
    for (final image in [false, true]) {
      final client = _Client();
      final transport = IoShower798Transport(
          client: client, requestTimeout: const Duration(milliseconds: 10));
      const request = Shower798Request(method: 'GET', path: 'test');
      await expectLater(
          image ? transport.getImageBase64(request) : transport.send(request),
          throwsA(isA<Shower798Exception>()
              .having((e) => e.message, 'message', contains('超时'))));
      expect(client.calls, 1);
      client.gate.complete(_Request());
      await Future<void>.delayed(Duration.zero);
    }
  });
}

class _Client implements HttpClient {
  final gate = Completer<HttpClientRequest>();
  int calls = 0;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    calls++;
    return gate.future;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  bool aborted = false;
  @override
  void abort([Object? exception, StackTrace? stackTrace]) => aborted = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
