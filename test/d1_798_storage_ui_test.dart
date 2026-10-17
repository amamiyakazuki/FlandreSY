import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/method_channel_shared_preferences.dart';
import 'package:flandresy/src/data/account_session_repository.dart';
import 'package:flandresy/src/data/shared_prefs_account_session_repository.dart';
import 'package:flandresy/src/profile/shower798_account_detail.dart';
import 'package:flandresy/src/profile/shower798_device_tile.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'package:flandresy/src/runtime/shui_runtime.dart';
import 'package:flandresy/src/runtime/shui_runtime_base.dart';
import 'package:flandresy/src/theme/shui_motion.dart';
import 'd1_798_consistency_test.dart' show a, b, account, initial;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('old list preserves raw data but never treats cached status as current',
      () async {
    final original = jsonEncode([
      {'id': 'a', 'name': 'A', 'lastStatus': '空闲'},
      {'id': 'b', 'name': 'B', 'lastStatus': '停止请求已确认'},
      {'id': 'c', 'name': 'C'},
    ]);
    SharedPreferences.setMockInitialValues({
      'shower798_mobile': 'old-account',
      'shower798_devices_json': original,
      'shower798_current_device_id': 'a',
    });
    final repo = SharedPrefsAccountSessionRepository();
    final old = (await repo.loadShower798())!;
    expect(old.devices.map((d) => d.displayStatus), everyElement('状态未查询'));
    expect(old.devices.first.lastStatus, '空闲');
    await repo.saveShower798(old);
    final loaded = (await repo.loadShower798())!;
    expect(loaded.account.mobile, 'old-account');
    expect(loaded.devices.map((d) => d.id), ['a', 'b', 'c']);
    expect(
        (await SharedPreferences.getInstance())
            .getString('shower798_devices_json'),
        original);
    await repo.clearShower798();
    expect((await repo.loadShower798())!.account.mobile, isEmpty);
    expect((await repo.loadShower798())!.devices.length, 3);
  });
  test(
      'snapshot takes precedence; corrupt snapshot is backed up without fallback to old identity',
      () async {
    SharedPreferences.setMockInitialValues({'shower798_mobile': 'old-account'});
    final repo = SharedPrefsAccountSessionRepository();
    await repo.saveShower798(initial);
    expect((await repo.loadShower798())!.account.mobile, account.mobile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shower798_snapshot_v2', '{broken');
    await expectLater(repo.loadShower798(), throwsA(anything));
    expect(prefs.getString('shower798_snapshot_v2'), '{broken');
    expect(prefs.getString('shower798_snapshot_v2_recovery_backup'), '{broken');
  });
  test(
      'single-write snapshot false/exception retains old account list selection and cache',
      () async {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance =
        MethodChannelSharedPreferencesStore();
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final disk = <String, Object>{};
    var mode = 'ok';
    var writes = 0;
    const channel = MethodChannel('plugins.flutter.io/shared_preferences');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAll') return Map.of(disk);
      if (call.method == 'setString') {
        writes++;
        if (mode == 'false') return false;
        if (mode == 'throw') throw PlatformException(code: 'disk');
        final args = call.arguments as Map;
        disk[args['key'] as String] = args['value'] as Object;
        return true;
      }
      throw StateError('unexpected ${call.method}');
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final repo = SharedPrefsAccountSessionRepository();
    await repo.saveShower798(initial);
    expect(writes, 1);
    final before = Map.of(disk);
    for (final failure in ['false', 'throw']) {
      mode = failure;
      await expectLater(
          repo.saveShower798(const Shower798Persisted(
              account: Shower798AccountUi(
                  mobile: 'other', uid: 'other', eid: 'other'),
              devices: [b],
              currentDeviceId: 'b')),
          throwsA(anything));
      final restored = (await repo.loadShower798())!;
      expect(restored.account.mobile, account.mobile);
      expect(restored.currentDeviceId, 'a');
      expect(restored.devices.single.id, 'a');
      expect(disk, before);
    }
    mode = 'ok';
    await repo.saveShower798(const Shower798Persisted(
        account: account, devices: [a, b], currentDeviceId: 'b'));
    expect((await repo.loadShower798())!.currentDeviceId, 'b');
  });
  testWidgets('cached idle never appears in a device tile', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Shower798DeviceTile(
                device: Shower798DeviceUi(id: 'a', name: 'A', lastStatus: '空闲'),
                isCurrent: false,
                onSelect: null))));
    expect(find.text('空闲'), findsNothing);
    expect(find.text('状态未查询'), findsOneWidget);
    expect(tester.widget<ShuiPressable>(find.byType(ShuiPressable)).enabled,
        isFalse);
  });
  testWidgets(
      'list error has its own banner and add does not discard retry input',
      (tester) async {
    String? submitted;
    final state = ShuiRuntimeBase.seedState().copyWith(
      shower798Account: account,
      shower798Login: const RuntimeActionStatus(
          state: RuntimeTaskState.success, message: '登录成功'),
      shower798DevicesStatus: const RuntimeActionStatus(
          state: RuntimeTaskState.failure, message: '列表保存失败'),
      shower798Devices: const [a],
    );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: Shower798AccountDetail(
      state: state,
      nowMillis: 0,
      onRequestCaptcha: () {},
      onSendSms: (_, __) {},
      onLogin: (_, __) {},
      onAddDevice: (id) {
        submitted = id;
      },
      onRefreshDevices: () {},
      onSelectDevice: (_) {},
      isDefault: false,
      onDefaultChanged: (_) {},
    )))));
    expect(find.text('登录成功'), findsOneWidget);
    expect(find.text('列表保存失败'), findsOneWidget);
    final input = find.byType(TextField).last;
    await tester.enterText(input, 'retry-device');
    await tester.ensureVisible(find.text('添加设备'));
    await tester.tap(find.text('添加设备'));
    await tester.pump();
    expect(submitted, 'retry-device');
    expect(tester.widget<TextField>(input).controller!.text, 'retry-device');
  });
}
