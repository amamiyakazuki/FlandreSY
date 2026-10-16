import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flandresy/src/data/permission_service.dart';
import 'package:flandresy/src/more/permission_check.dart';
import 'package:flandresy/src/widgets/qr_scanner_screen.dart';
import 'package:flandresy/src/shell/shui_shell_chrome.dart';
import 'c5a_permissions_test.dart' show TestPermissionBackend;

void main() {
  testWidgets('first launch is explanation only with no permission claim',
      (tester) async {
    var confirmed = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FirstLaunchPermissionDialog(onConfirm: () => confirmed++))));
    expect(find.textContaining('通知'), findsNothing);
    expect(find.textContaining('使用扫码'), findsOneWidget);
    await tester.tap(find.text('知道了，继续'));
    expect(confirmed, 1);
  });
  testWidgets(
      'permission page entry is read-only; explicit camera request refreshes view',
      (tester) async {
    final backend = TestPermissionBackend(target: TargetPlatform.iOS);
    await tester.pumpWidget(MaterialApp(
        home: PermissionCheckScreen(
            permissions: ShuiPermissionService(backend: backend))));
    await tester.pumpAndSettle();
    expect(backend.requests, isEmpty);
    expect(find.text(iosZhuliUnavailable), findsOneWidget);
    expect(find.text('申请蓝牙权限'), findsNothing);
    await tester.tap(find.text('申请相机权限'));
    await tester.pumpAndSettle();
    expect(backend.requests.single, [Permission.camera]);
    expect(find.text('权限已授予'), findsWidgets);
    expect(find.text('申请相机权限'), findsNothing);
  });
  testWidgets(
      'permanent denial never opens settings automatically; failure shown truthfully',
      (tester) async {
    final backend = TestPermissionBackend(target: TargetPlatform.iOS)
      ..values[Permission.camera] = PermissionStatus.permanentlyDenied
      ..settingsOpened = false;
    await tester.pumpWidget(MaterialApp(
        home: PermissionCheckScreen(
            permissions: ShuiPermissionService(backend: backend))));
    await tester.pumpAndSettle();
    expect(backend.settingsCalls, 0);
    expect(find.text('申请相机权限'), findsNothing);
    await tester.tap(find.text('打开系统设置'));
    await tester.pumpAndSettle();
    expect(find.text('未能打开系统设置，请手动进入应用设置'), findsOneWidget);
    expect(backend.settingsCalls, 1);
    backend.values[Permission.camera] = PermissionStatus.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('权限已授予'), findsOneWidget);
    expect(backend.requests, isEmpty);
  });
  testWidgets(
      'request failure can retry, and pending request disables repeat taps',
      (tester) async {
    final gate = Completer<Map<Permission, PermissionStatus>>();
    final backend = TestPermissionBackend(target: TargetPlatform.iOS)
      ..requester = (_) => gate.future;
    await tester.pumpWidget(MaterialApp(
        home: PermissionCheckScreen(
            permissions: ShuiPermissionService(backend: backend))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('申请相机权限'));
    await tester.pump();
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '申请相机权限'))
            .onPressed,
        isNull);
    gate.completeError(StateError('permission'));
    await tester.pumpAndSettle();
    expect(find.text('权限申请未完成，请重试'), findsOneWidget);
    backend.requester = null;
    await tester.tap(find.text('申请相机权限'));
    await tester.pumpAndSettle();
    expect(find.text('申请相机权限'), findsNothing);
  });
  testWidgets('unmounted page ignores late request completion', (tester) async {
    final gate = Completer<Map<Permission, PermissionStatus>>();
    final backend = TestPermissionBackend(target: TargetPlatform.iOS)
      ..requester = (_) => gate.future;
    await tester.pumpWidget(MaterialApp(
        home: PermissionCheckScreen(
            permissions: ShuiPermissionService(backend: backend))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('申请相机权限'));
    await tester.pumpWidget(const SizedBox());
    gate.complete({Permission.camera: PermissionStatus.granted});
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'scanner denial does not start camera; settings return checks without prompting again',
      (tester) async {
    final backend = TestPermissionBackend(target: TargetPlatform.iOS)
      ..values[Permission.camera] = PermissionStatus.permanentlyDenied
      ..settingsOpened = false;
    await tester.pumpWidget(MaterialApp(
        home: QrScannerScreen(
            permissions: ShuiPermissionService(backend: backend))));
    await tester.pumpAndSettle();
    expect(find.text('相机权限尚未就绪'), findsOneWidget);
    expect(backend.requests, isEmpty);
    await tester.tap(find.text('打开系统设置'));
    await tester.pumpAndSettle();
    expect(find.text('未能打开系统设置，请手动进入应用设置'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(backend.requests, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets('permission page supports narrow large text with iOS explanation',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: PermissionCheckScreen(
            permissions: ShuiPermissionService(
                backend: TestPermissionBackend(target: TargetPlatform.iOS)))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(iosZhuliUnavailable));
    expect(tester.takeException(), isNull);
  });
}
