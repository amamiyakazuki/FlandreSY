import 'package:flandresy/src/runtime/models/account_session.dart';
import 'package:flandresy/src/runtime/models/washer_order.dart';
import 'package:flandresy/src/runtime/washer_state.dart';
import 'package:flandresy/src/washer/washer_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_runtime.dart';

const _account = '13800000001';
const _now = 1700000000000;

ShuiHomeState _state([WasherOrderUi? order]) => const ShuiHomeState().copyWith(
      ujingAccount: const UjingAccountUi(
          mobile: _account, userId: 'u', serviceSubjectId: 's'),
      washer: WasherState(orders: [if (order != null) order]),
    );

WasherOrderUi _order(String status, {String text = '', int remain = 0}) =>
    WasherOrderUi(
      orderId: 'order-1',
      deviceNo: '0003091',
      statusText: text,
      payPrice: '¥2.10',
      status: status,
      remainTimeSeconds: remain,
      refreshedAtMillis: _now,
      ownerAccountKey: _account,
      createdAtMillis: _now,
      endsAtMillis: WasherOrderUi.expectedEndsAt(status, remain, _now, 0),
    );

Future<List<String>> _pump(WidgetTester tester, ShuiHomeState state) async {
  final calls = <String>[];
  await tester.pumpWidget(MaterialApp(
    home: WasherOrderScreen(
      state: state,
      nowMillis: () => _now,
      onBack: () {},
      onCreateOrder: (_, __, ___, ____) => calls.add('create'),
      onPay: (autoStart) => calls.add('pay:$autoStart'),
      onStart: () => calls.add('start'),
      onStop: () => calls.add('stop'),
      onCancel: () => calls.add('cancel'),
      onRefresh: () => calls.add('refresh'),
      onRemoveLocal: () => calls.add('remove'),
    ),
  ));
  await tester.pump();
  return calls;
}

void main() {
  testWidgets('without an order the page shows the ordering form',
      (tester) async {
    await _pump(tester, _state());
    expect(find.text('洗衣下单'), findsOneWidget);
    expect(find.text('套餐选择'), findsOneWidget);
    expect(find.text('当前订单'), findsNothing);
  });

  testWidgets('an existing order hides the form and shows only the order',
      (tester) async {
    final calls = await _pump(tester, _state(_order(WasherStatus.unpaid)));
    expect(find.text('洗衣订单'), findsOneWidget);
    expect(find.text('套餐选择'), findsNothing);
    expect(find.text('待支付'), findsOneWidget);
    expect(find.text('支付后自动启动'), findsOneWidget);
    await tester.tap(find.text('支付宝支付'));
    expect(calls, ['pay:true']);
  });

  testWidgets('running order shows a live countdown and a stop action',
      (tester) async {
    await _pump(tester, _state(_order(WasherStatus.running, remain: 35 * 60)));
    expect(find.text('35:00'), findsOneWidget);
    expect(find.text('提前停止'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('starting order offers no stop button', (tester) async {
    await _pump(tester, _state(_order(WasherStatus.starting)));
    expect(find.text('提前停止'), findsNothing);
    expect(find.text('刷新状态'), findsOneWidget);
  });

  testWidgets('unknown status can be removed locally after confirmation',
      (tester) async {
    final calls = await _pump(tester, _state(_order('60', text: '已退款')));
    expect(find.text('已退款'), findsOneWidget);
    expect(find.textContaining('未识别的状态'), findsOneWidget);

    await tester.tap(find.text('移除本机记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保留'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    await tester.tap(find.text('移除本机记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除'));
    await tester.pumpAndSettle();
    expect(calls, ['remove']);
  });
}
