// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used indirectly via FlandreApp; this golden locks the current Shell/Home visual baseline.
// Reference: P_PLAN/FlandreSY-Complete-Functions-and-UI-Design-Reference.md §4.2 HomeScreen visual layout.

import 'package:flandresy/src/app/flandre_app.dart';
import 'package:flandresy/src/theme/shui_motion.dart';
import 'package:flandresy/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'support/seed_devices.dart';

void main() {
  testGoldens('Home shell first screen after permission dialog', (
    tester,
  ) async {
    await _pumpHomeAfterPermission(tester);

    await screenMatchesGolden(tester, 'home_shell_first_screen');
  });

  testGoldens('Home shell respects Android safe areas', (tester) async {
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 28);
    addTearDown(tester.view.resetPadding);

    await _pumpHomeAfterPermission(tester);

    await screenMatchesGolden(tester, 'home_shell_android_safe_area');
  });

  testGoldens('Home washer summary stays aligned on phone viewport', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 28);
    addTearDown(tester.view.resetPadding);

    await _pumpHomeAfterPermission(tester);
    await tester.drag(find.byType(Scrollable), const Offset(0, -520));
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'home_shell_washer_summary_aligned');
  });
}

Future<void> _pumpHomeAfterPermission(WidgetTester tester) async {
  await tester.pumpWidgetBuilder(
    FlandreApp(devices: goldenSeededDeviceRepository()),
    surfaceSize: const Size(
      AppCustomTokens.adaptivePhoneMaxWidth,
      AppCustomTokens.goldenPhoneHeight,
    ),
  );
  await tester.pump(ShuiMotion.opening);
  await tester.pumpAndSettle();

  await tester.tap(find.text('好，开启权限'));
  await tester.pumpAndSettle();
}
