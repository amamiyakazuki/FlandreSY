import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/device_import.dart';
import 'package:flandresy/src/data/local_device_repository.dart';
import 'package:flandresy/src/devices/device_dialogs.dart';
import 'package:flandresy/src/devices/device_import_dialog.dart';
import 'package:flandresy/src/devices/devices_screen.dart';
import 'support/test_runtime.dart';
import 'c2_devices_test.dart' show ControlledDevices, washer, water;

Widget app(Widget child, {double scale = 1}) => MaterialApp(
    home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: child)));
void main() {
  testWidgets('rename save failure preserves input and allows retry',
      (tester) async {
    var calls = 0;
    final gate = Completer<DeviceChangeResult>();
    await tester.pumpWidget(app(EditDeviceNameDialog(
        initialName: '原名',
        onDismiss: () {},
        onSave: (value) {
          expect(value, '新名称');
          calls++;
          return gate.future;
        })));
    await tester.enterText(find.byType(TextField), '新名称');
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.tap(find.text('保存'));
    expect(calls, 1);
    gate.complete(const DeviceChangeResult(false, '设备保存失败，原列表已保留，请重试'));
    await tester.pumpAndSettle();
    expect(find.text('新名称'), findsOneWidget);
    expect(find.textContaining('设备保存失败'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'import failure retry and stale preview confirmation retain clipboard data',
      (tester) async {
    final repo = ControlledDevices([washer])..fail = true;
    final runtime = TestRuntime(devices: repo);
    addTearDown(runtime.dispose);
    await runtime.ready;
    await tester.pumpWidget(app(DeviceImportDialog(
        runtime: runtime, raw: LocalDeviceCodec.encode([water]))));
    await tester.tap(find.text('确认替换'));
    await tester.pumpAndSettle();
    expect(find.textContaining('保存失败'), findsOneWidget);
    expect(runtime.state.localDevices.single.id, washer.id);
    repo.fail = false;
    await runtime.addPresetWasherDevice('额外设备', '${washer.qrUrl}-new');
    await tester.tap(find.text('确认替换'));
    await tester.pumpAndSettle();
    expect(find.textContaining('列表已变化'), findsOneWidget);
    expect(find.textContaining('替换当前 2 条'), findsOneWidget);
    expect(runtime.state.localDevices.length, 2);
    await tester.tap(find.text('确认替换'));
    await tester.pumpAndSettle();
    expect(runtime.state.localDevices.single.id, water.id);
    await tester.pump(const Duration(seconds: 5));
  });
  testWidgets('cancel preview leaves original records untouched',
      (tester) async {
    final runtime = TestRuntime(devices: ControlledDevices([washer]));
    addTearDown(runtime.dispose);
    await runtime.ready;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => DeviceImportDialog(
                        runtime: runtime,
                        raw: LocalDeviceCodec.encode([water]))),
                child: const Text('打开')))));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(runtime.state.localDevices.single.id, washer.id);
  });
  testWidgets(
      'narrow large-text import error and partial refresh remain readable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = TestRuntime();
    addTearDown(runtime.dispose);
    await runtime.ready;
    await tester.pumpWidget(
        app(DeviceImportDialog(runtime: runtime, raw: '[{}]'), scale: 1.8));
    await tester.pumpAndSettle();
    expect(find.textContaining('第 1 条'), findsOneWidget);
    expect(find.text('确认替换'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(app(
        DevicesScreen(
            state: const ShuiHomeState().copyWith(
                localDevices: [
                  washer.copyWith(lastStatus: '可下单', statusQueryFailed: true)
                ],
                devicesRefresh: const RuntimeActionStatus(
                    state: RuntimeTaskState.failure,
                    message: '查询成功 1 条，失败 1 条，跳过 0 条；失败项保留上次结果')),
            onAdd: () {},
            onBack: () {},
            onRefresh: () {},
            onOpenDevice: (_) {},
            onMenu: (_) {}),
        scale: 1.8));
    await tester.pumpAndSettle();
    expect(find.textContaining('本次查询失败；上次结果'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
