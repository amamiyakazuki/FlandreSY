import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/design_tokens.dart';
import 'package:flandresy/src/home/cards/hot_water_card.dart';
import 'package:flandresy/src/hotwater/hotwater_detail_screen.dart';
import 'package:flandresy/src/runtime/fake_shui_runtime.dart';
import 'package:flandresy/src/runtime/hotwater_state.dart';
import 'package:flandresy/src/runtime/models/hotwater_history.dart';
import 'package:flandresy/src/widgets/shui_components.dart';

ShuiHomeState _state({
  HotwaterSessionPhase? phase,
  bool running = true,
  RuntimeTaskState start = RuntimeTaskState.success,
  RuntimeTaskState stop = RuntimeTaskState.idle,
  RuntimeTaskState history = RuntimeTaskState.idle,
  String? historyMessage,
  bool records = false,
  BathSystemPreference system = BathSystemPreference.zhuli,
}) =>
    ShuiHomeState(
        bathSystemPreference: system,
        hotwater: HotwaterState(
          running: running,
          start: RuntimeActionStatus(state: start, message: '状态测试'),
          stop: RuntimeActionStatus(state: stop),
          historyStatus:
              RuntimeActionStatus(state: history, message: historyMessage),
          session: phase == null
              ? null
              : HotwaterSession(
                  id: 's',
                  account: 'a',
                  system: system,
                  simulated: true,
                  deviceId: 'd',
                  startedAtMillis: 1,
                  baselineOrderIds: const [],
                  phase: phase),
          history: records
              ? const [
                  HotwaterHistoryUi(
                      time: '12:00',
                      deviceId: '旧设备',
                      amount: '¥1.00',
                      status: '已完成',
                      orderId: 'old')
                ]
              : const [],
        ));

Future<void> _home(WidgetTester tester, ShuiHomeState state,
    {VoidCallback? start, VoidCallback? stop}) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: SingleChildScrollView(
              child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                      width: 328,
                      child: HotWaterCard(
                          state: state,
                          onStartHotwater: start ?? () {},
                          onStopHotwater: stop ?? () {},
                          onSwitchBathSystem: () {},
                          onOpenDetail: () {})))))));
  await tester.pumpAndSettle();
}

Future<void> _detail(WidgetTester tester, ShuiHomeState state) async {
  await tester.pumpWidget(MaterialApp(
      home: HotwaterDetailScreen(
          state: state, onBack: () {}, onStart: () {}, onStop: () {})));
  await tester.pumpAndSettle();
}

Color? _statusColor(WidgetTester tester) =>
    tester.widget<Text>(find.text('≋  状态测试')).style?.color;

void main() {
  testWidgets(
      'home green requires confirmed active, uncertain orange, loading never green',
      (tester) async {
    for (final entry in [
      (_state(phase: HotwaterSessionPhase.active), AppColors.serviceGreen),
      (_state(phase: HotwaterSessionPhase.uncertain), AppColors.serviceOrange),
      (
        _state(
            phase: HotwaterSessionPhase.uncertain,
            start: RuntimeTaskState.loading),
        AppColors.primary
      ),
      (
        _state(
            phase: HotwaterSessionPhase.uncertain,
            stop: RuntimeTaskState.loading),
        AppColors.primary
      ),
      (_state(phase: HotwaterSessionPhase.starting), AppColors.primary),
      (_state(phase: HotwaterSessionPhase.preparing), AppColors.primary),
      (_state(), AppColors.primary),
      (
        _state(phase: HotwaterSessionPhase.active, running: false),
        AppColors.primary
      ),
      (
        _state(
            phase: HotwaterSessionPhase.active,
            start: RuntimeTaskState.loading),
        AppColors.primary
      ),
      (
        _state(
            phase: HotwaterSessionPhase.active, stop: RuntimeTaskState.loading),
        AppColors.primary
      ),
      (
        _state(
            phase: HotwaterSessionPhase.active,
            start: RuntimeTaskState.paymentInProgress),
        AppColors.primary
      ),
    ]) {
      await _home(tester, entry.$1);
      expect(_statusColor(tester), entry.$2);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('login and failed actions take warning precedence over active',
      (tester) async {
    for (final warning in [
      RuntimeTaskState.failure,
      RuntimeTaskState.loginRequired,
      RuntimeTaskState.permissionRequired,
      RuntimeTaskState.unavailable
    ]) {
      for (final fromStop in [false, true]) {
        await _home(
            tester,
            _state(
                phase: HotwaterSessionPhase.active,
                start: fromStop ? RuntimeTaskState.success : warning,
                stop: fromStop ? warning : RuntimeTaskState.idle));
        expect(_statusColor(tester), AppColors.serviceOrange);
      }
    }
  });

  testWidgets(
      'same text keeps home dimensions and both controls clickable across colors',
      (tester) async {
    Size? baseline;
    var starts = 0, stops = 0;
    for (final state in [
      _state(phase: HotwaterSessionPhase.active),
      _state(phase: HotwaterSessionPhase.uncertain),
      _state(
          phase: HotwaterSessionPhase.active, start: RuntimeTaskState.loading),
      _state(
          phase: HotwaterSessionPhase.active,
          start: RuntimeTaskState.loginRequired),
    ]) {
      await _home(tester, state, start: () => starts++, stop: () => stops++);
      final size = tester.getSize(find.byType(HotWaterCard));
      baseline ??= size;
      expect(size, baseline);
      final buttons = tester
          .widgetList<PrimaryGradientButton>(find.byType(PrimaryGradientButton))
          .toList();
      expect(buttons, hasLength(2));
      await tester.tap(find.text('启动热水'));
      await tester.tap(find.text('停止热水'));
      await tester.pumpAndSettle();
    }
    expect(starts, 4);
    expect(stops, 4);
  });

  testWidgets(
      'only successful empty history shows the empty state; missing messages have fallbacks',
      (tester) async {
    final fallback = {
      RuntimeTaskState.idle: '热水历史尚未加载',
      RuntimeTaskState.loading: '正在加载热水历史',
      RuntimeTaskState.failure: '热水历史加载失败，请稍后重试',
      RuntimeTaskState.loginRequired: '请先登录住理账号后查询历史',
      RuntimeTaskState.permissionRequired: '查询热水历史所需权限尚未授予',
      RuntimeTaskState.paymentInProgress: '正在处理热水历史请求',
      RuntimeTaskState.unavailable: '热水历史暂不可用，请稍后重试',
    };
    for (final status in RuntimeTaskState.values) {
      for (final message in [null, '', '   ']) {
        await _detail(tester, _state(history: status, historyMessage: message));
        if (status == RuntimeTaskState.success) {
          expect(find.text('暂无热水历史'), findsOneWidget);
        } else {
          expect(find.text('暂无热水历史'), findsNothing);
          expect(find.text(fallback[status]!), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets(
      'history failure/loading keeps old rows and specific error messages',
      (tester) async {
    for (final status in RuntimeTaskState.values) {
      await _detail(tester,
          _state(history: status, records: true, historyMessage: '保留具体原因'));
      expect(find.text('设备 旧设备'), findsOneWidget);
      expect(find.text('保留具体原因'), findsOneWidget);
      expect(find.text('暂无热水历史'), findsNothing);
    }
    await _detail(
        tester, _state(history: RuntimeTaskState.failure, records: true));
    expect(find.text('热水历史加载失败，请稍后重试'), findsOneWidget);
    expect(find.text('设备 旧设备'), findsOneWidget);
    expect(find.text('暂无热水历史'), findsNothing);
  });

  testWidgets(
      '798 retains its explanation without Zhuli history or query state',
      (tester) async {
    await _detail(
        tester,
        _state(
            system: BathSystemPreference.shower798,
            history: RuntimeTaskState.failure,
            records: true,
            historyMessage: '住理失败原因'));
    expect(find.text('慧生活798暂不提供账号历史，本页不会混入住理订单。'), findsOneWidget);
    expect(find.text('设备 旧设备'), findsNothing);
    expect(find.text('住理失败原因'), findsNothing);
    expect(find.text('暂无热水历史'), findsNothing);
    expect(find.text('启动洗浴'), findsOneWidget);
    expect(find.text('停止洗浴'), findsOneWidget);
  });
}
