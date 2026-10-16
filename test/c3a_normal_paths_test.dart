import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/adapters/io_ujing_transport.dart';
import 'package:flandresy/src/data/adapters/io_shower798_transport.dart';
import 'package:flandresy/src/data/adapters/ujing_http_adapter.dart';
import 'package:flandresy/src/data/adapters/real_shower798_adapter.dart';
import 'package:flandresy/src/data/adapters/ujing_adapter.dart';
import 'package:flandresy/src/data/adapters/shower798_adapter.dart';
import 'package:flandresy/src/data/adapters/payment_launcher.dart';
import 'support/loopback_service.dart';

void main() {
  test(
      'Ujing normal captcha/login/water/washer/payment/control paths over HTTP',
      () async {
    final server = await LoopbackService.start();
    addTearDown(server.close);
    var status = '10';
    final replies = <String, Object?>{
      'login': {'token': 'test-token', 'userId': 'test-user'},
      'home/scanCode': {'service': 'water'},
      'water/serviceSubject/changeWithScan': {'newServiceSubjectId': 'school'},
      'app/water/serviceSubject/currentInfo': {'balance': '1000'},
      'water/createWaterOrder': {'orderId': 123},
      'water/waterOrderDetail': {'orderId': 123, 'orderStatus': '0'},
      'devices/scanWasherCode': {
        'result': {
          'deviceId': 'washer',
          'deviceTypeId': 1,
          'createOrderEnabled': true
        }
      },
      'app/washer/devices/program/info': {
        'storeId': 'store',
        'deviceWashModel': [
          {'workModelId': 1, 'time': 35, 'basePrice': 300}
        ]
      },
      'orders/create': {'orderId': 'washer-order'},
      'payment/arguments': {
        'payInfo': {'orderInfo': 'synthetic-payment'}
      },
    };
    server.respond = (path) {
      if (path == 'orders/washer-order/detail') {
        return {
          'code': 0,
          'data': {'orderId': 'washer-order', 'status': status}
        };
      }
      if (path.endsWith('/control/start')) status = '40';
      if (path.endsWith('/control/stop')) status = '50';
      if (replies.containsKey(path)) return {'code': 0, 'data': replies[path]};
      expect([
        'captcha',
        'orders/washer-order/control/start',
        'orders/washer-order/control/stop',
        'orders/washer-order/cancel'
      ], contains(path));
      return {'code': 0};
    };
    final launcher = _Payment(() => status = '20');
    final adapter = UjingHttpAdapter(
        transport: IoUjingTransport(baseUrl: server.url, client: server.client),
        launcher: launcher);
    await adapter.requestCaptcha('test-account');
    expect((await adapter.login('test-account', '1234')).userId, 'test-user');
    await adapter.checkAccountValidity();
    final water = await adapter
        .scanAndCreateWaterOrder('https://example.invalid/?cd=test-device');
    expect(water.order!.orderId, '123');
    expect((await adapter.refreshWaterOrder(water.order!)).orderStatus, '0');
    final program = await adapter.scanWasher('test-qr');
    expect(program.createOrderEnabled, isTrue);
    final order = await adapter.createWasherOrder(
        program: program, washModelId: 1, temperatureId: 0, orderSeq: 1);
    expect(order.orderId, 'washer-order');
    expect((await adapter.payWasherOrder(order)).status, '20');
    expect(launcher.calls, 1);
    expect((await adapter.startWasherOrder(order, 2100)).status, '40');
    expect((await adapter.stopWasherOrder(order)).status, '50');
    await adapter.cancelWasherOrder(order);
    expect(
        server.paths.where((p) => p.endsWith('/control/start')), hasLength(1));
    // Invalid payment arguments must never reach the launcher.
    replies['payment/arguments'] = {
      'payInfo': {'orderInfo': {}}
    };
    await expectLater(
        adapter.payWasherOrder(order), throwsA(isA<UjingException>()));
    expect(launcher.calls, 1);
  });
  test(
      '798 normal image/SMS/login/list/status/favorite/control paths over HTTP',
      () async {
    final server = await LoopbackService.start();
    addTearDown(server.close);
    final adapter = RealShower798Adapter(
        transport: IoShower798Transport(
            baseUrl: server.url.substring(0, server.url.length - 1),
            client: server.client));
    server.raw = 'synthetic-image-bytes';
    final captcha = await adapter.requestCaptcha();
    expect(utf8.decode(base64Decode(captcha.imageBase64)),
        'synthetic-image-bytes');
    server.raw = null;
    server.respond = (path) => switch (path) {
          'acc/login' => {
              'code': 0,
              'data': {
                'al': {'token': 'test-token', 'uid': 'user', 'eid': 'e'}
              }
            },
          'ui/app/master' => {
              'code': 0,
              'data': {
                'account': {},
                'favos': [
                  {'id': 'one', 'name': 'first'},
                  {'id': 'two', 'name': 'second'}
                ]
              }
            },
          'ui/app/dev/status' => {
              'code': 0,
              'data': {
                'device': {
                  'gene': {'status': 99}
                }
              }
            },
          _ => {'code': 0},
        };
    await adapter.sendSmsCode(
        doubleRandom: captcha.doubleRandom,
        imageCaptcha: '1234',
        phone: 'test-account');
    expect((await adapter.login('test-account', '1234')).token, 'test-token');
    expect((await adapter.loadDevices()).map((d) => d.id), ['two', 'one']);
    await adapter.checkAccountValidity();
    expect(await adapter.isDeviceIdle('one'), isTrue);
    await adapter.addDevice('three');
    await adapter.deleteDevice('three');
    await adapter.startShower('one');
    await adapter.stopShower('one');
    expect(server.paths.where((p) => p == 'dev/start'), hasLength(1));
    expect(server.paths.where((p) => p == 'dev/end'), hasLength(1));
    server.respond = (_) => {
          'code': 0,
          'data': {'account': {}, 'favos': []}
        };
    expect(await adapter.loadDevices(), isEmpty);
    server.respond = (_) => {
          'code': 0,
          'data': {
            'device': {
              'gene': {'status': 1}
            }
          }
        };
    expect(await adapter.isDeviceIdle('one'), isFalse);
    server.respond = (_) => {'code': 0, 'data': {}};
    await expectLater(
        adapter.isDeviceIdle('one'), throwsA(isA<Shower798Exception>()));
  });
}

class _Payment implements PaymentLauncher {
  _Payment(this.onPay);
  final void Function() onPay;
  int calls = 0;
  @override
  Future<String> payWithAlipay(String orderInfo) async {
    expect(orderInfo, 'synthetic-payment');
    calls++;
    onPay();
    return '9000';
  }
}
