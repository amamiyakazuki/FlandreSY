import 'package:flandresy/src/data/app_bootstrap.dart';
import 'package:flandresy/src/data/history_repository.dart';
import 'package:flandresy/src/runtime/live_clock.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'package:flandresy/src/runtime/models/hotwater_history.dart';
import 'package:flandresy/src/runtime/models/washer_order.dart';
import 'package:flandresy/src/runtime/models/water_order.dart';
import 'package:flandresy/src/runtime/washer_state.dart';
import 'package:flandresy/src/stats/spending_screen.dart';
import 'package:flandresy/src/stats/spending_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'c4_history_ownership_test.dart' show HistoryAdapter;
import 'support/test_runtime.dart';

const _a = '13800000001';
const _b = '13800000002';
final _nov = DateTime(2026, 11, 14, 12).millisecondsSinceEpoch;
final _oct = DateTime(2026, 10, 3, 9).millisecondsSinceEpoch;

WasherOrderHistoryUi _washer(String id, String status, String price, int at,
        {String owner = _a}) =>
    WasherOrderHistoryUi(
        orderId: id,
        deviceNo: 'd',
        status: status,
        statusText: '',
        payPrice: price,
        ownerAccountKey: owner,
        createdAtMillis: at);

WaterOrderHistoryUi _water(String id, double yuan, int at,
        {String owner = _a}) =>
    WaterOrderHistoryUi(
        orderId: id,
        deviceNo: 'w',
        status: '完成',
        payment: yuan,
        warmWaterMl: 300,
        waterSeconds: 10,
        completedAt: '12:00',
        ownerAccountKey: owner,
        completedAtMillis: at);

ShuiHomeState _state() => const ShuiHomeState().copyWith(
      ujingAccount:
          const UjingAccountUi(mobile: _a, userId: 'u', serviceSubjectId: 's'),
      zhuli: const ZhuliSession(phone: 'Z'),
      washer: WasherState(history: [
        _washer('w1', WasherStatus.finished, '¥2.10', _nov),
        _washer('w2', WasherStatus.finished, '¥3.50', _oct),
        _washer('w3', WasherStatus.cancelled, '¥2.10', _nov),
        _washer('w4', WasherStatus.removed, '¥2.10', _nov),
        _washer('w5', WasherStatus.finished, '¥9.90', _nov, owner: _b),
        _washer('w6', WasherStatus.finished, '¥1.00', 0),
      ]),
      waterHistory: [
        _water('d1', 0.35, _nov),
        _water('d2', 0.20, _nov, owner: _b),
        _water('d3', 0.10, 0),
      ],
      hotwaterHistory: [
        const HotwaterHistoryUi(
            time: '2026-11-02 21:15:00',
            deviceId: 'h',
            amount: '¥1.20',
            status: '完成',
            orderId: 'h1',
            ownerAccount: 'Z'),
        const HotwaterHistoryUi(
            time: '2026-11-03 21:15:00',
            deviceId: 'h',
            amount: '金额未知',
            status: '完成',
            orderId: 'h2',
            ownerAccount: 'Z'),
        const HotwaterHistoryUi(
            time: '2026-11-04 21:15:00',
            deviceId: 'h',
            amount: '¥5.00',
            status: '完成',
            orderId: 'h3',
            ownerAccount: 'other'),
      ],
    );

void main() {
  test('counts only charged records of the current accounts, by month', () {
    final stats = SpendingStats.compute(_state());
    final nov = stats.month(const MonthKey(2026, 11));
    final byService = {for (final s in nov.services) s.service: s};
    expect(byService[SpendingService.washer]!.amountFen, 210);
    expect(byService[SpendingService.washer]!.count, 1);
    expect(byService[SpendingService.drinking]!.amountFen, 35);
    expect(byService[SpendingService.hotwater]!.amountFen, 120);
    expect(byService[SpendingService.hotwater]!.count, 1);
    expect(nov.totalFen, 365);
    expect(stats.month(const MonthKey(2026, 10)).totalFen, 350);
    expect(stats.undatedCount, 2);
    expect(stats.firstMonth, const MonthKey(2026, 10));
  });

  test('recent months include empty months and cross year boundaries', () {
    final months = SpendingStats.compute(_state())
        .recentMonths(const MonthKey(2027, 1), 4);
    expect(months.map((m) => '${m.month}'),
        ['2026年10月', '2026年11月', '2026年12月', '2027年1月']);
    expect(months.map((m) => m.totalFen), [350, 365, 0, 0]);
  });

  test('amount and time parsing', () {
    expect(parseYuanToFen('¥2.10'), 210);
    expect(parseYuanToFen('3'), 300);
    expect(parseYuanToFen('金额未知'), 0);
    expect(parseRecordTime('2026-11-02 21:15:00'),
        DateTime(2026, 11, 2, 21, 15).millisecondsSinceEpoch);
    expect(parseRecordTime('1762089300'), 1762089300000);
    expect(parseRecordTime('today'), isNull);
  });

  test(
      'refreshing hot-water history keeps records older than the server window',
      () async {
    final now = DateTime(2026, 11, 14, 12);
    String at(DateTime t) =>
        '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} 10:00:00';
    final old = HotwaterHistoryUi(
        time: at(now.subtract(const Duration(days: 60))),
        deviceId: 'h',
        amount: '¥1.00',
        status: '完成',
        orderId: 'old',
        ownerAccount: 'Z');
    final staleRecent = HotwaterHistoryUi(
        time: at(now.subtract(const Duration(days: 3))),
        deviceId: 'h',
        amount: '¥1.00',
        status: '完成',
        orderId: 'stale',
        ownerAccount: 'Z');
    final api = HistoryAdapter()
      ..loader = () async => [
            HotwaterHistoryUi(
                time: at(now.subtract(const Duration(days: 1))),
                deviceId: 'h',
                amount: '¥2.00',
                status: '完成',
                orderId: 'fresh'),
          ];
    final runtime = TestRuntime(
      hotwater: api,
      clock: FixedLiveClock(now.millisecondsSinceEpoch),
      history: InMemoryHistoryRepository(history: [old, staleRecent]),
      initial: PersistedSnapshot(
          bathSystem: BathSystemPreference.zhuli,
          zhuli: const ZhuliSession(phone: 'Z'),
          hotwaterHistory: [old, staleRecent]),
    );
    addTearDown(runtime.dispose);
    await runtime.ready;
    await runtime.loadHotwaterHistory();
    expect(runtime.state.currentHotwaterHistory.map((h) => h.orderId),
        unorderedEquals(['fresh', 'old']));
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('spending page reads clearly at 320 width, text scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: SpendingScreen(state: _state(), nowMillis: _nov, onBack: () {}),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('2026年11月'), findsOneWidget);
      expect(find.text('¥3.65'), findsWidgets);
      expect(find.text('洗衣 · 1 笔'), findsOneWidget);
      expect(find.textContaining('2 笔旧记录没有日期'), findsOneWidget);

      await tester.tap(find.byTooltip('上个月'));
      await tester.pumpAndSettle();
      expect(find.text('2026年10月'), findsOneWidget);
      expect(find.text('¥3.50'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
