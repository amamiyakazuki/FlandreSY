import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/adapters/ble_response.dart';
import 'package:flandresy/src/data/adapters/hotwater_adapter.dart';
import 'package:flandresy/src/data/adapters/http_request_deadline.dart';
import 'package:flandresy/src/data/adapters/io_ujing_transport.dart';
import 'package:flandresy/src/data/adapters/ujing_adapter.dart';
import 'package:flandresy/src/data/adapters/ujing_transport.dart';

void main() {
  for (final headersHang in [true, false]) {
    test(
        'Ujing ${headersHang ? 'headers' : 'body'} stall aborts once without retry',
        () async {
      final client = _Client(headersHang: headersHang);
      final transport = IoUjingTransport(
          client: client, requestTimeout: const Duration(milliseconds: 20));
      await expectLater(
          transport.send(
              const UjingRequest(method: 'GET', path: 'detail', appCode: 'CA')),
          throwsA(isA<UjingException>()
              .having((e) => e.message, 'message', contains('超时'))));
      expect(client.request.abortCount, 1);
      expect(client.calls, 1);
      if (headersHang) client.request.responseGate.complete(client.response);
      client.response.controller.add('{"code":0,"data":{}}'.codeUnits);
      await client.response.controller.close();
      await Future<void>.delayed(Duration.zero);
      expect(client.calls, 1);
    });
  }
  for (final phase in ['response headers', 'response body']) {
    test('total deadline aborts hung $phase and rejects late effects',
        () async {
      final gate = Completer<void>();
      final request = _Request();
      var lateEffect = false;
      final operation = HttpRequestDeadline.run(
          const Duration(milliseconds: 20), (deadline) async {
        deadline.attach(request);
        // Same attached-request phase as waiting for headers or body.
        await gate.future;
        deadline.check();
        lateEffect = true;
      });
      await expectLater(operation, throwsA(isA<TimeoutException>()));
      expect(request.abortCount, 1);
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(lateEffect, isFalse);
    });
  }

  test(
      'early BLE CRC failure is handled before write completes and subscription cancels',
      () async {
    final notifications = StreamController<List<int>>(sync: true);
    final write = Completer<void>();
    final future = writeAndAwaitZhuliFrame(
        notifications: notifications.stream,
        expectedTypes: [3],
        timeout: const Duration(milliseconds: 100),
        write: () {
          notifications.add([0, 0, 240]);
          return write.future;
        });
    await expectLater(
        future,
        throwsA(isA<HotwaterException>()
            .having((e) => e.message, 'message', contains('CRC'))));
    expect(notifications.hasListener, isFalse);
    write.complete();
    await notifications.close();
  });

  test('early BLE notification stream error is surfaced and listener released',
      () async {
    final notifications = StreamController<List<int>>(sync: true);
    final write = Completer<void>();
    final error = StateError('notify failure');
    final future = writeAndAwaitZhuliFrame(
        notifications: notifications.stream,
        expectedTypes: [3],
        timeout: const Duration(milliseconds: 100),
        write: () {
          notifications.addError(error);
          return write.future;
        });
    await expectLater(future, throwsA(same(error)));
    expect(notifications.hasListener, isFalse);
    write.complete();
    await notifications.close();
  });

  test('unrelated BLE frames ignored; matching frame during write is retained',
      () async {
    final notifications = StreamController<List<int>>(sync: true);
    final future = writeAndAwaitZhuliFrame(
        notifications: notifications.stream,
        expectedTypes: [3],
        write: () async {
          notifications.add([0]);
          notifications.add([0, 0, 2]);
          notifications.add([0, 0, 3, 42]);
        });
    expect(await future, '0000032a');
    expect(notifications.hasListener, isFalse);
    await notifications.close();
  });

  test('BLE write failure releases listener even with no response', () async {
    final notifications = StreamController<List<int>>(sync: true);
    final error = StateError('write failed');
    final future = writeAndAwaitZhuliFrame(
        notifications: notifications.stream,
        expectedTypes: [3],
        write: () async => throw error);
    await expectLater(future, throwsA(same(error)));
    expect(notifications.hasListener, isFalse);
    await notifications.close();
  });
}

class _Request implements HttpClientRequest {
  int abortCount = 0;
  final responseGate = Completer<HttpClientResponse>();
  @override
  final headers = _Headers();
  @override
  Future<HttpClientResponse> close() => responseGate.future;
  @override
  void abort([Object? exception, StackTrace? stackTrace]) => abortCount++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Headers implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  final controller = StreamController<List<int>>();
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      controller.stream.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements HttpClient {
  _Client({required bool headersHang}) {
    if (!headersHang) request.responseGate.complete(response);
  }
  final request = _Request();
  final response = _Response();
  int calls = 0;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    calls++;
    return request;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
