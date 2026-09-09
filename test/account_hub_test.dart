import 'package:flandresy/src/profile/account_hub_screen.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'package:flandresy/src/runtime/shui_home_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets('circular account entries fit width $width with large text',
        (tester) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AccountKind? selected;
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
              size: Size(width, 740), textScaler: const TextScaler.linear(2)),
          child: AccountHubScreen(
            state: const ShuiHomeState(),
            onBack: () {},
            onSelect: (kind) => selected = kind,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      for (final kind in AccountKind.values) {
        final entry = find.byKey(ValueKey('account-entry-${kind.name}'));
        final circle = find.descendant(
            of: entry,
            matching: find.byWidgetPredicate((widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).shape ==
                    BoxShape.circle));
        expect(circle, findsOneWidget);
        expect(tester.getSize(circle).width, tester.getSize(circle).height);
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(selected, kind);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
