import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flandresy/src/data/adapters/io_ujing_transport.dart';
import 'package:flandresy/src/data/adapters/ujing_adapter.dart';
import 'package:flandresy/src/data/adapters/ujing_transport.dart';
import 'package:flandresy/src/data/legacy_data_migration.dart';
import 'package:flandresy/src/more/legacy_recovery_sheet.dart';
import 'package:flandresy/src/more/more_options_screen.dart';
import 'support/memory_migration_store.dart';
import 'support/test_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'SharedPrefs backup only contains known ordinary keys and preserves actual types',
      () async {
    SharedPreferences.setMockInitialValues({
      'use_simulated_backend': false,
      'ujing_mobile': 'a',
      'local_devices_json': '[]',
      'some_secure_token': 'DO-NOT-COPY',
      'unrelated_setting': 123
    });
    final store = SharedPrefsLegacyMigrationStore();
    final migration = LegacyDataMigration(store);
    await migration.prepare();
    final raw = (await store.read(LegacyDataMigration.backupKey))!;
    expect(raw, isNot(contains('DO-NOT-COPY')));
    expect(jsonDecode(raw)['values'], {
      'use_simulated_backend': false,
      'ujing_mobile': 'a',
      'local_devices_json': '[]'
    });
    final original = raw;
    await (await SharedPreferences.getInstance())
        .setString('ujing_mobile', 'new');
    await LegacyDataMigration(store).prepare();
    expect(await store.read(LegacyDataMigration.backupKey), original);
  });

  for (final payload in <Map<String, dynamic>>[
    {},
    {'code': 0},
    {
      'code': 'error',
      'data': {'orderId': '1'}
    },
    {
      'code': 1,
      'data': {'orderId': '1'}
    },
    {'code': 0, 'data': {}},
  ]) {
    test('strict migration request rejects envelope $payload', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(payload));
        await request.response.close();
      });
      final client = _LoopbackHttpOverrides().createHttpClient(null);
      addTearDown(() async {
        client.close(force: true);
        await subscription.cancel();
        await server.close(force: true);
      });
      final transport = IoUjingTransport(
          baseUrl: 'http://127.0.0.1:${server.port}/', client: client);
      await expectLater(
          transport.send(const UjingRequest(
              method: 'GET',
              path: 'orders/1/detail',
              appCode: 'BA',
              requireVerifiedEnvelope: true)),
          throwsA(isA<UjingException>()));
    });
  }
  test('strict envelope accepts an explicit success over the loopback server',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    final subscription = server.listen((request) async {
      requests++;
      request.response.write(jsonEncode({
        'code': 0,
        'data': {'orderId': '1'}
      }));
      await request.response.close();
    });
    final client = _LoopbackHttpOverrides().createHttpClient(null);
    addTearDown(() async {
      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    });
    final transport = IoUjingTransport(
        baseUrl: 'http://127.0.0.1:${server.port}/', client: client);
    expect(
        await transport.send(const UjingRequest(
            method: 'GET',
            path: 'orders/1/detail',
            appCode: 'BA',
            requireVerifiedEnvelope: true)),
        {'orderId': '1'});
    expect(requests, 1);
  });
  testWidgets('more options has no simulation switch and exposes recovery',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MoreOptionsScreen(
            onBack: () {},
            onImportDevices: () {},
            onExportDevices: () {},
            onOpenLogs: () {},
            onLegacyRecovery: () {})));
    expect(find.byType(Switch), findsNothing);
    expect(find.text('使用模拟后端'), findsNothing);
    expect(find.text('旧数据保全'), findsOneWidget);
  });
  testWidgets(
      'recovery sheet explains pending state and routes to accounts at narrow width',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final migration =
        LegacyDataMigration(MemoryMigrationStore({'ujing_mobile': 'a'}));
    final runtime = TestRuntime(migration: migration);
    addTearDown(runtime.dispose);
    await runtime.ready;
    var opened = false;
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!),
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showLegacyRecoverySheet(
                        context, runtime, () => opened = true),
                    child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('U净：需要重新登录'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('前往账号中心'));
    await tester.tap(find.text('前往账号中心'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
  });
}

// Flutter widget binding replaces HttpClient with HTTP 400; these protocol tests
// explicitly use a real client restricted to the loopback server.
class _LoopbackHttpOverrides extends HttpOverrides {}
