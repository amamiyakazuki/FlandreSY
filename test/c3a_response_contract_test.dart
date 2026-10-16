import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/adapters/io_ujing_transport.dart';
import 'package:flandresy/src/data/adapters/io_shower798_transport.dart';
import 'package:flandresy/src/data/adapters/ujing_transport.dart';
import 'package:flandresy/src/data/adapters/shower798_transport.dart';
import 'package:flandresy/src/data/adapters/ujing_adapter.dart';
import 'package:flandresy/src/data/adapters/shower798_adapter.dart';
import 'package:flandresy/src/data/adapters/ujing_http_adapter.dart';
import 'package:flandresy/src/data/adapters/real_shower798_adapter.dart';
import 'package:flandresy/src/runtime/models/washer_order.dart';
import 'support/fake_payment_launcher.dart';
import 'support/loopback_service.dart';

void main() {
  for (final shower in [false, true]) {
    final name = shower ? '798' : 'Ujing';
    Future<Object?> send(LoopbackService server) => shower
        ? IoShower798Transport(
                baseUrl: server.url.substring(0, server.url.length - 1),
                client: server.client)
            .send(const Shower798Request(method: 'GET', path: 'ack'))
        : IoUjingTransport(baseUrl: server.url, client: server.client).send(
            const UjingRequest(method: 'GET', path: 'ack', appCode: 'BA'));
    Matcher error({bool invalid = false}) => shower
        ? isA<Shower798Exception>()
            .having((e) => e.authInvalid, 'authInvalid', invalid)
        : isA<UjingException>()
            .having((e) => e.authInvalid, 'authInvalid', invalid);
    for (final payload in <Object?>[
      {},
      {'code': null},
      {'code': '0'},
      {'code': 'error'},
      {'code': true},
      {'code': false},
      {'code': []},
      {'code': {}},
      {'code': 1},
      [],
      null,
    ]) {
      test(
          '$name rejects ambiguous envelope $payload without auth invalidation',
          () async {
        final server = await LoopbackService.start();
        addTearDown(server.close);
        server.response = payload;
        await expectLater(send(server), throwsA(error()));
        expect(server.paths, ['ack']);
      });
    }
    for (final code in <num>[0, 0.0]) {
      test('$name accepts numeric $code confirmation without data', () async {
        final server = await LoopbackService.start();
        addTearDown(server.close);
        server.response = {'code': code};
        await send(server);
        expect(server.paths, ['ack']);
      });
    }
    for (final http in [401, 403, 500]) {
      test('$name HTTP $http overrides a success envelope', () async {
        final server = await LoopbackService.start();
        addTearDown(server.close);
        server.status = http;
        await expectLater(send(server), throwsA(error(invalid: http != 500)));
        expect(server.paths, ['ack']);
      });
    }
    test('$name rejects broken JSON', () async {
      final server = await LoopbackService.start();
      addTearDown(server.close);
      server.raw = '{broken';
      await expectLater(send(server), throwsA(error()));
    });
  }
  for (final data in <Object?>[
    null,
    [],
    {},
    {'status': []}
  ]) {
    test('washer detail rejects incomplete data $data', () async {
      final server = await LoopbackService.start();
      addTearDown(server.close);
      server.response = {'code': 0, 'data': data};
      await expectLater(ujingFor(server).refreshWasherOrder(order),
          throwsA(isA<UjingException>()));
    });
  }
  test('798 malformed master data does not invalidate credentials', () async {
    final server = await LoopbackService.start();
    addTearDown(server.close);
    final adapter = showerFor(server);
    for (final data in <Object?>[
      null,
      [],
      {},
      {'account': null},
      {'account': {}, 'favos': {}}
    ]) {
      server.response = {'code': 0, 'data': data};
      await expectLater(
          adapter.loadDevices(),
          throwsA(isA<Shower798Exception>()
              .having((e) => e.authInvalid, 'authInvalid', false)));
      expect(adapter.lastToken, 'test-token');
    }
  });
  test('malformed login tokens never replace existing adapter credentials',
      () async {
    final server = await LoopbackService.start();
    addTearDown(server.close);
    final ujing = ujingFor(server);
    final shower = showerFor(server);
    server.response = {
      'code': 0,
      'data': {
        'token': {},
        'al': {'token': []}
      }
    };
    await expectLater(
        ujing.login('new-account', '1234'), throwsA(isA<UjingException>()));
    await expectLater(shower.login('new-account', '1234'),
        throwsA(isA<Shower798Exception>()));
    expect(ujing.lastToken, 'test-token');
    expect(shower.lastToken, 'test-token');
  });
  test(
      'conflicting order ID cannot become a terminal result for requested order',
      () async {
    final server = await LoopbackService.start();
    addTearDown(server.close);
    server.response = {
      'code': 0,
      'data': {'orderId': 'other-order', 'status': '50'}
    };
    await expectLater(ujingFor(server).refreshWasherOrder(order),
        throwsA(isA<UjingException>()));
    expect(server.paths, ['orders/order-1/detail']);
  });
  test(
      'missing water balance cannot report insufficient funds or proceed to creation',
      () async {
    final server = await LoopbackService.start();
    addTearDown(server.close);
    server.response = {'code': 0, 'data': {}};
    await expectLater(ujingFor(server).scanAndCreateWaterOrder('test-device'),
        throwsA(isA<UjingException>()));
    expect(server.paths, [
      'water/serviceSubject/changeWithScan',
      'app/water/serviceSubject/currentInfo'
    ]);
  });
}

UjingHttpAdapter ujingFor(LoopbackService server) => UjingHttpAdapter(
    transport: IoUjingTransport(baseUrl: server.url, client: server.client),
    token: 'test-token',
    launcher: const FakePaymentLauncher());

RealShower798Adapter showerFor(LoopbackService server) => RealShower798Adapter(
    transport: IoShower798Transport(
        baseUrl: server.url.substring(0, server.url.length - 1),
        client: server.client),
    token: 'test-token');

const order = WasherOrderUi(
    orderId: 'order-1',
    deviceNo: 'washer-1',
    statusText: '待支付',
    payPrice: '3',
    status: '10',
    ownerAccountKey: 'test-account');
