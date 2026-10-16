import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flandresy/src/data/app_bootstrap.dart';
import 'package:flandresy/src/shell/shui_shell.dart';
import 'support/test_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/orders/orders_screen.dart';
import 'package:flandresy/src/hotwater/hotwater_history_panel.dart';
import 'package:flandresy/src/runtime/live_clock.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'c4_history_ownership_test.dart' show old, record, HistoryAdapter;

ShuiHomeState stateFor(String account,
        {RuntimeTaskState status = RuntimeTaskState.idle}) =>
    const ShuiHomeState().copyWith(
      zhuli: ZhuliSession(phone: account),
      hotwaterHistory: [
        old,
        record('A-device').ownedBy('A'),
        record('B-device').ownedBy('B')
      ],
      hotwaterHistoryStatus: RuntimeActionStatus(state: status),
    );

Widget orders(ShuiHomeState state, VoidCallback load, {bool active = true}) =>
    MaterialApp(
        home: OrdersScreen(
      state: state,
      clock: const SystemLiveClock(),
      onBack: () {},
      onOpenWasherOrder: () {},
      onOpenDrinking: () {},
      onRefreshHotwater: load,
      active: active,
    ));

void main() {
  testWidgets('preservation failure message remains visible while logged out',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: HotwaterHistoryPanel(
      state: stateFor('').copyWith(
          hotwaterHistoryStatus: const RuntimeActionStatus(
              state: RuntimeTaskState.failure, message: '旧数据保全未完成，请先重试保全')),
    ))));
    expect(find.text('旧数据保全未完成，请先重试保全'), findsOneWidget);
    expect(find.text('设备 A-device'), findsNothing);
  });

  testWidgets(
      'shell orders entry loads history without visiting controls; failure can retry',
      (tester) async {
    final api = HistoryAdapter()
      ..loader = () async => throw TimeoutException('offline');
    await tester.pumpWidget(MaterialApp(
        home: TestRuntimeScope(
      hotwater: api,
      initial: PersistedSnapshot(
        bathSystem: BathSystemPreference.zhuli,
        permissionIntroSeen: true,
        zhuli: const ZhuliSession(phone: 'A'),
        hotwaterHistory: [
          old,
          record('A-device').ownedBy('A'),
          record('B-device').ownedBy('B')
        ],
      ),
      child: const ShuiShell(),
    )));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(api.calls, 0);
    await tester.tap(find.text('订单'));
    await tester.pumpAndSettle();
    expect(api.calls, 1);
    expect(find.text('设备 A-device'), findsOneWidget);
    expect(find.text('设备 B-device'), findsNothing);
    expect(find.textContaining('历史未更新'), findsOneWidget);
    api.loader = () async => [record('new-A')];
    await tester.ensureVisible(find.text('刷新热水历史'));
    await tester.tap(find.text('刷新热水历史'));
    await tester.pumpAndSettle();
    expect(api.calls, 2);
    expect(find.text('设备 new-A'), findsOneWidget);
    expect(find.text('设备 A-device'), findsNothing);
    expect(find.text('热水历史已加载'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'visible entry loads once; ordinary rebuild does not; returning tab and account do',
      (tester) async {
    var loads = 0;
    void load() => loads++;
    await tester.pumpWidget(orders(stateFor('A'), load, active: false));
    expect(loads, 0);
    await tester.pumpWidget(orders(stateFor('A'), load));
    expect(loads, 1);
    await tester.pumpWidget(
        orders(stateFor('A', status: RuntimeTaskState.success), load));
    expect(loads, 1);
    await tester.pumpWidget(orders(stateFor('B'), load));
    expect(loads, 2);
    await tester.pumpWidget(orders(stateFor('B'), load, active: false));
    await tester.pumpWidget(orders(stateFor('B'), load));
    expect(loads, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'switching back to hotwater loads and manual retry remains available',
      (tester) async {
    var loads = 0;
    await tester.pumpWidget(
        orders(stateFor('A', status: RuntimeTaskState.failure), () => loads++));
    expect(loads, 1);
    await tester.tap(find.text('饮水'));
    await tester.pumpAndSettle();
    expect(loads, 1);
    await tester.tap(find.text('热水'));
    await tester.pumpAndSettle();
    expect(loads, 2);
    expect(find.text('热水历史加载失败，请稍后重试'), findsOneWidget);
    expect(find.text('以下为本地缓存，尚未确认最新记录'), findsOneWidget);
    await tester.tap(find.text('刷新热水历史'));
    expect(loads, 3);
  });

  for (final account in ['A', 'B', '']) {
    testWidgets(
        'panel displays only current owner and separates legacy: $account',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: HotwaterHistoryPanel(state: stateFor(account))))));
      expect(find.text('设备 A-device'),
          account == 'A' ? findsOneWidget : findsNothing);
      expect(find.text('设备 B-device'),
          account == 'B' ? findsOneWidget : findsNothing);
      expect(find.text('设备 old-device'), findsNothing);
      expect(find.text('旧记录（归属待核对）· 1'), findsOneWidget);
      await tester.tap(find.text('旧记录（归属待核对）· 1'));
      await tester.pumpAndSettle();
      expect(find.text('设备 old-device'), findsOneWidget);
      expect(find.text('这些旧记录已保留，无法确认所属账号，不计入当前账号历史。'), findsOneWidget);
      if (account.isEmpty) expect(find.text('请先登录住理账号后查询历史'), findsOneWidget);
    });
  }

  testWidgets('loading disables retry and does not show successful empty state',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: HotwaterHistoryPanel(
                state: stateFor('C', status: RuntimeTaskState.loading),
                onRefresh: () => calls++))));
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '正在加载历史'))
            .onPressed,
        isNull);
    expect(find.text('暂无热水历史'), findsNothing);
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('invisible/disposed entry does not dispatch scheduled work',
      (tester) async {
    var calls = 0;
    await tester
        .pumpWidget(orders(stateFor('A'), () => calls++, active: false));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(calls, 0);
  });

  testWidgets(
      'narrow large-font order view and expanded archive remain readable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: OrdersScreen(
            state: stateFor('A', status: RuntimeTaskState.failure),
            clock: const SystemLiveClock(),
            onBack: () {},
            onOpenWasherOrder: () {},
            onOpenDrinking: () {},
            onRefreshHotwater: () {})));
    await tester.pumpAndSettle();
    final legacy = find.text('旧记录（归属待核对）· 1');
    await tester.ensureVisible(legacy);
    await tester.tap(legacy);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('设备 old-device'));
    expect(tester.takeException(), isNull);
  });
}
