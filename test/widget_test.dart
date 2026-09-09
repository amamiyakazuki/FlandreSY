// Design tokens used indirectly via FlandreApp; this smoke test verifies the current bounded module shell.

import 'package:flandresy/src/app/flandre_app.dart';
import 'package:flandresy/src/profile/account_detail_screen.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Flandre shell shows Home first screen', (tester) async {
    await tester.pumpWidget(const FlandreApp());
    await tester.pumpAndSettle(const Duration(milliseconds: 700));

    expect(find.text('芙兰水衣'), findsWidgets);
    expect(find.text('进行中'), findsOneWidget);
    expect(find.text('热水控制页'), findsOneWidget);
    expect(find.text('扫码使用'), findsOneWidget);
    expect(find.text('洗衣设备'), findsOneWidget);
  });

  testWidgets('permission dialog can be dismissed', (tester) async {
    await tester.pumpWidget(const FlandreApp());
    await tester.pumpAndSettle(const Duration(milliseconds: 700));

    expect(find.text('先给小助手一点权限吧'), findsOneWidget);
    await tester.tap(find.text('好，开启权限'));
    await tester.pumpAndSettle();
    expect(find.text('先给小助手一点权限吧'), findsNothing);
  });

  testWidgets('account hub opens and routes to selected account',
      (tester) async {
    await tester.pumpWidget(const FlandreApp());
    await tester.pumpAndSettle(const Duration(milliseconds: 700));

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('账号中心'));
    await tester.pumpAndSettle();

    expect(find.text('账号中心'), findsOneWidget);
    expect(find.text('住理生活'), findsOneWidget);
    expect(find.text('慧生活798'), findsOneWidget);
    expect(find.text('U净'), findsOneWidget);

    final ujingTitle = find.text('U净');
    await tester.ensureVisible(ujingTitle);
    await tester.tap(ujingTitle);
    await tester.pumpAndSettle();
    expect(find.text('U净账号'), findsWidgets);
    expect(
        tester
            .widget<AccountDetailScreen>(find.byType(AccountDetailScreen))
            .kind,
        AccountKind.ujing);
    for (final kind in [AccountKind.zhuli, AccountKind.shower798]) {
      tester
          .widget<AccountDetailScreen>(find.byType(AccountDetailScreen))
          .onBack();
      await tester.pumpAndSettle();
      final entry = find.byKey(ValueKey('account-entry-${kind.name}'));
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<AccountDetailScreen>(find.byType(AccountDetailScreen))
              .kind,
          kind);
    }
  });
}
