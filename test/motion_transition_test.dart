import 'package:flandresy/src/runtime/fake_shui_runtime.dart';
import 'package:flandresy/src/theme/shui_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flandresy/src/widgets/shui_animated_list.dart';
import 'package:flandresy/src/widgets/shui_overlay_host.dart';
import 'package:flandresy/src/devices/device_dialogs.dart';
import 'package:flandresy/src/app/flandre_app.dart';
import 'package:flandresy/src/shell/shui_shell_chrome.dart';
import 'package:flandresy/src/shell/shui_shell.dart';
import 'package:flandresy/src/profile/account_detail_screen.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('press feedback invokes once and ignores disabled input',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ShuiPressable(
          enabled: true,
          onTap: () => taps += 1,
          child: const SizedBox(width: 120, height: 48),
        ),
      ),
    ));

    final center = tester.getCenter(find.byType(ShuiPressable));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 100));
    expect(taps, 0);
    await gesture.up();
    await tester.pump();
    expect(taps, 1);
    await tester.tapAt(center);
    await tester.pump();
    expect(taps, 2);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ShuiPressable(
          enabled: false,
          onTap: () => taps += 1,
          child: const SizedBox(width: 120, height: 48),
        ),
      ),
    ));
    await tester.tap(find.byType(ShuiPressable));
    expect(taps, 2);
  });

  testWidgets(
      'drag cancellation, disabling while pressed, keyboard and reduced motion',
      (tester) async {
    var taps = 0;
    var enabled = true;
    late StateSetter update;
    await tester.pumpWidget(
        MaterialApp(home: StatefulBuilder(builder: (context, setState) {
      update = setState;
      return MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Center(
              child: ShuiPressable(
                  enabled: enabled,
                  onTap: () => taps++,
                  child: const SizedBox(width: 120, height: 48))));
    })));
    final target = find.byType(ShuiPressable);
    final gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    update(() => enabled = false);
    await tester.pump();
    await gesture.up();
    expect(taps, 0);
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1);
    update(() => enabled = true);
    await tester.pump();
    final drag = await tester.startGesture(tester.getCenter(target));
    await drag.moveBy(const Offset(250, 0));
    await drag.cancel();
    await tester.pumpAndSettle();
    expect(taps, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, 1);
  });

  testWidgets(
      'list retains survivors during removal and handles rapid insertion',
      (tester) async {
    var items = ['a', 'b'];
    late StateSetter update;
    await tester.pumpWidget(
        MaterialApp(home: StatefulBuilder(builder: (context, setState) {
      update = setState;
      return ShuiAnimatedList<String>(
          items: items,
          identity: (item) => item,
          empty: const Text('empty'),
          itemBuilder: (item, index) =>
              SizedBox(height: 48, child: Text(item)));
    })));
    update(() => items = ['b']);
    await tester.pump();
    expect(find.text('a'), findsOneWidget);
    update(() => items = ['c', 'b']);
    await tester.pumpAndSettle();
    expect(find.text('a'), findsNothing);
    expect(find.text('b'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
    update(() => items = []);
    await tester.pumpAndSettle();
    expect(find.text('empty'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'modal exit blocks input and large text keyboard layout remains scrollable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var visible = true;
    var taps = 0;
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 640),
                viewInsets: EdgeInsets.only(bottom: 250),
                textScaler: TextScaler.linear(2)),
            child: StatefulBuilder(builder: (context, setState) {
              update = setState;
              return Material(
                  child: Stack(children: [
                Positioned.fill(
                    child: GestureDetector(
                        onTap: () => taps++,
                        child: const ColoredBox(color: Colors.white))),
                ShuiOverlayHost(
                    child: visible
                        ? EditDeviceNameDialog(
                            initialName: '设备',
                            onDismiss: () => update(() => visible = false),
                            onSave: (_) {})
                        : null)
              ]));
            }))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    update(() => visible = false);
    await tester.pump();
    await tester.tapAt(const Offset(10, 10));
    expect(taps, 0);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    expect(taps, 1);
  });

  testWidgets(
      'system back preserves account hierarchy and tabs retain category',
      (tester) async {
    await tester.pumpWidget(const FlandreApp());
    await tester.pumpAndSettle(const Duration(milliseconds: 700));
    final permission = find.text('好，开启权限');
    if (permission.evaluate().isNotEmpty) {
      await tester.tap(permission);
      await tester.pumpAndSettle();
    }
    void tab(MainTab tab) => tester
        .widget<WavyBottomBar>(find.byType(WavyBottomBar))
        .onTabSelected(tab);
    tab(MainTab.orders);
    await tester.pumpAndSettle();
    await tester.tap(find.text('洗衣'));
    await tester.pumpAndSettle();
    tab(MainTab.profile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('账号中心'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('住理生活'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountDetailScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AccountDetailScreen), findsNothing);
    expect(find.text('账号中心'), findsOneWidget);
    tab(MainTab.home);
    await tester.pump();
    tab(MainTab.devices);
    await tester.pump();
    tab(MainTab.orders);
    await tester.pumpAndSettle();
    expect(find.text('暂无洗衣订单'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('completed water result survives active order cleanup', () async {
    final runtime = FakeShuiRuntime();
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.scanDrinkingWaterAndCreateOrder('CD-TEST');
    expect(runtime.state.currentWaterOrder, isNotNull);
    await runtime.refreshCurrentDrinkingWaterOrder();
    expect(runtime.state.currentWaterOrder, isNull);
    expect(runtime.state.waterResult?.orderId, '1102876060');
    expect(runtime.state.waterOrder.state, RuntimeTaskState.success);

    runtime.resetDrinkingWaterTransient();
    expect(runtime.state.waterResult, isNull);
  });
}
