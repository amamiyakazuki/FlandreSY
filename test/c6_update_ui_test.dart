import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/more/about_dialog.dart';
import 'package:flandresy/src/more/more_options_screen.dart';
import 'package:flandresy/src/more/version_check.dart';

VersionCheckResult available({List<String> changes = const ['更新']}) =>
    VersionCheckResult(
        current: '2.1.4',
        state: UpdateState.available,
        message: '发现可用更新',
        latest: VersionInfo(
            version: '2.2.0',
            releaseDate: '2026-10-17',
            changelog: changes,
            downloadUrl: '$kReleasePage/download/v2.2.0/app-release.apk',
            buildNumber: 5000),
        actionUrl: '$kReleasePage/download/v2.2.0/app-release.apk',
        actionLabel: '打开下载链接');

Widget page(VersionCheckResult result, Future<bool> Function(Uri) opener,
        {VoidCallback? retry}) =>
    MaterialApp(
        home: Scaffold(
            body: VersionCheckDialogCard(
                result: result,
                onDismiss: () {},
                openUrl: opener,
                onRetry: retry)));

void main() {
  for (final outcome in ['false', 'error', 'true']) {
    testWidgets('link $outcome gives truthful feedback and can retry',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(page(available(), (_) async {
        calls++;
        if (outcome == 'error') throw StateError('fail');
        return outcome == 'true';
      }));
      await tester.tap(find.text('打开下载链接'));
      await tester.pumpAndSettle();
      expect(
          find.text(outcome == 'true'
              ? '已打开链接，请在浏览器中继续。'
              : outcome == 'false'
                  ? '无法打开链接，请重试。'
                  : '打开链接失败，请重试。'),
          findsOneWidget);
      await tester.tap(find.text('打开下载链接'));
      await tester.pumpAndSettle();
      expect(calls, 2);
    });
  }
  testWidgets(
      'pending link coalesces taps and ignores completion after unmount',
      (tester) async {
    final pending = Completer<bool>();
    var calls = 0;
    await tester.pumpWidget(page(available(), (_) {
      calls++;
      return pending.future;
    }));
    await tester.tap(find.text('打开下载链接'));
    await tester.pump();
    await tester.tap(find.text('正在打开…'));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    pending.complete(false);
    await tester.pump();
    expect(tester.takeException(), null);
  });
  testWidgets('iOS channel explains limitation and never offers APK',
      (tester) async {
    await tester.pumpWidget(page(
        const VersionCheckResult(
            current: '2.1.4',
            state: UpdateState.noChannel,
            message: '暂未提供 iOS 更新渠道',
            actionUrl: kReleasePage,
            actionLabel: '查看发布说明'),
        (_) async => true));
    expect(find.text('暂未提供 iOS 更新渠道'), findsOneWidget);
    expect(find.text('打开下载链接'), findsNothing);
    expect(find.text('已是最新版本'), findsNothing);
    await tester.tap(find.text('查看发布说明'));
    await tester.pumpAndSettle();
    expect(find.text('已打开链接，请在浏览器中继续。'), findsOneWidget);
  });
  testWidgets('unknown version offers a real retry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(page(
        const VersionCheckResult(
            current: '未知', state: UpdateState.unknown, message: '无法确认当前版本'),
        (_) async => true,
        retry: () => retries++));
    await tester.tap(find.text('重试'));
    expect(retries, 1);
  });
  testWidgets('untrusted injected destination cannot reach launcher',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(page(
        const VersionCheckResult(
            current: '2.1.4',
            state: UpdateState.available,
            message: 'test',
            actionUrl: 'file:///tmp/a.apk',
            actionLabel: '打开下载链接'), (_) async {
      calls++;
      return true;
    }));
    await tester.tap(find.text('打开下载链接'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('打开链接失败，请重试。'), findsOneWidget);
  });
  testWidgets('long notes remain scrollable at narrow width and large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 640), textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: VersionCheckDialogCard(
                    result: available(
                        changes: List.filled(30, '长更新说明需要完整展示且按钮可以滚动到达')),
                    onDismiss: () {},
                    openUrl: (_) async => true)))));
    expect(tester.takeException(), null);
    await tester.ensureVisible(find.text('打开下载链接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开下载链接'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
  });
  testWidgets(
      'more page coalesces checks and refreshes displayed metadata after retry',
      (tester) async {
    final pending = Completer<VersionCheckResult>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: MoreOptionsScreen(
            onBack: () {},
            onImportDevices: () {},
            onExportDevices: () {},
            onOpenLogs: () {},
            checkVersion: () {
              calls++;
              return calls == 1 ? pending.future : Future.value(available());
            })));
    await tester.tap(find.text('检查版本'));
    await tester.pump();
    await tester.tap(find.text('检查版本'));
    expect(calls, 1);
    pending.complete(const VersionCheckResult(
        current: '未知', state: UpdateState.unknown, message: '无法确认当前版本'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('发现新版本'), findsOneWidget);
    await tester.tap(find.text('知道啦'));
    await tester.pumpAndSettle();
    expect(find.text('当前版本 2.1.4'), findsOneWidget);
  });
  testWidgets('more page ignores a check that completes after disposal',
      (tester) async {
    final pending = Completer<VersionCheckResult>();
    await tester.pumpWidget(MaterialApp(
        home: MoreOptionsScreen(
            onBack: () {},
            onImportDevices: () {},
            onExportDevices: () {},
            onOpenLogs: () {},
            checkVersion: () => pending.future)));
    await tester.tap(find.text('检查版本'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete(available());
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
  });
}
