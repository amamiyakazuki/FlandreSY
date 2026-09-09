import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flandresy/src/data/app_bootstrap.dart';
import 'package:flandresy/src/data/settings_repository.dart';
import 'package:flandresy/src/data/shared_prefs_settings_repository.dart';
import 'package:flandresy/src/home/cards/hot_water_card.dart';
import 'package:flandresy/src/runtime/fake_shui_runtime.dart';
import 'package:flandresy/src/widgets/shui_components.dart';

void main() {
  test('fresh settings are unselected and saved values survive recreation',
      () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SharedPrefsSettingsRepository();
    expect(await settings.loadBathSystem(), BathSystemPreference.none);
    expect(await InMemorySettingsRepository().loadBathSystem(),
        BathSystemPreference.none);
    for (final system in BathSystemPreference.values) {
      await settings.saveBathSystem(system);
      expect(await SharedPrefsSettingsRepository().loadBathSystem(), system);
    }
    await settings.saveBathSystem(BathSystemPreference.none);
    expect(await SharedPrefsSettingsRepository().loadBathSystem(),
        BathSystemPreference.none);
  });

  test(
      'successful login selects default, clearing persists without clearing account',
      () async {
    final settings = InMemorySettingsRepository();
    final runtime = FakeShuiRuntime(
      settings: settings,
      initial: const PersistedSnapshot(bathSystem: BathSystemPreference.none),
    );
    addTearDown(runtime.dispose);
    await runtime.loginZhuli('13800000000', 'password');
    expect(runtime.state.bathSystemPreference, BathSystemPreference.zhuli);
    await runtime.setBathSystem(BathSystemPreference.none);
    expect(runtime.state.zhuli.isLoggedIn, isTrue);
    expect(await settings.loadBathSystem(), BathSystemPreference.none);
    await runtime.loginShower798('13800000000', '123456');
    expect(runtime.state.bathSystemPreference, BathSystemPreference.shower798);
    await runtime.setBathSystem(BathSystemPreference.none);
    expect(runtime.state.shower798Account, isNotNull);
    expect(await settings.loadBathSystem(), BathSystemPreference.none);
  });

  testWidgets('unselected home has no enabled water controls or empty warning',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: HotWaterCard(
      state: const ShuiHomeState(),
      onStartHotwater: () => fail('No selected system'),
      onStopHotwater: () => fail('No selected system'),
      onSwitchBathSystem: () => opened = true,
      onOpenDetail: () {},
    ))));
    await tester.pumpAndSettle();
    expect(find.textContaining('未选择系统'), findsOneWidget);
    expect(find.text('⚠'), findsNothing);
    for (final button in tester.widgetList<PrimaryGradientButton>(
        find.byType(PrimaryGradientButton))) {
      expect(button.enabled, isFalse);
    }
    await tester.tap(find.text('选择系统'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });
}
