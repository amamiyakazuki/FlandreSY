// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used indirectly via FlandreApp; this smoke test verifies the current bounded module shell.

import 'package:flandresy/src/app/flandre_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Flandre shell shows Home first screen', (tester) async {
    await tester.pumpWidget(const FlandreApp());
    await tester.pumpAndSettle(const Duration(milliseconds: 700));

    expect(find.text('芙兰水衣'), findsWidgets);
    expect(find.text('进行中'), findsOneWidget);
    expect(find.text('热水控制'), findsOneWidget);
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
}
