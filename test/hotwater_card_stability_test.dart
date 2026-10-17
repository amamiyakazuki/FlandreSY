import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/home/cards/hot_water_card.dart';
import 'package:flandresy/src/runtime/shui_runtime.dart';
import 'package:flandresy/src/runtime/hotwater_state.dart';

const longError = '启动指令已发送，但结果尚未确认。请检查设备实际供水情况，不要重复启动，也不要根据历史记录判断设备已经停止。';
ShuiHomeState stateFor(RuntimeTaskState task,
        {String? message,
        bool stopping = false,
        BathSystemPreference system = BathSystemPreference.zhuli}) =>
    ShuiHomeState(
      bathSystemPreference: system,
      hotwater: HotwaterState(
        start: RuntimeActionStatus(
            state: stopping ? RuntimeTaskState.idle : task,
            message: stopping ? '热水待启动' : message),
        stop: stopping
            ? RuntimeActionStatus(state: task, message: message)
            : const RuntimeActionStatus(),
      ),
    );

Future<void> mount(
    WidgetTester tester, ShuiHomeState state, double width, double scale,
    {VoidCallback? start, VoidCallback? stop, VoidCallback? change}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Scaffold(
          body: SingleChildScrollView(
              child: RepaintBoundary(
                  key: const ValueKey('capture-hotwater'),
                  child: HotWaterCard(
                      state: state,
                      onStartHotwater: start ?? () {},
                      onStopHotwater: stop ?? () {},
                      onSwitchBathSystem: change ?? () {},
                      onOpenDetail: () {}))))));
  await tester.pumpAndSettle();
}

void main() {
  test(
      'all compact titles fit six characters and uncertain outcomes remain uncertain',
      () {
    for (final system in BathSystemPreference.values) {
      for (final task in RuntimeTaskState.values) {
        for (final phase in HotwaterSessionPhase.values) {
          final state = stateFor(task, system: system).copyWith(
              hotwater: HotwaterState(
            running: true,
            start: RuntimeActionStatus(state: task, message: longError),
            session: HotwaterSession(
                id: 's',
                account: 'a',
                system: system,
                simulated: false,
                deviceId: 'd',
                startedAtMillis: 1,
                baselineOrderIds: const [],
                phase: phase),
          ));
          final copy = HotwaterStatusCopy.fromState(state);
          expect(copy.title.runes.length, inInclusiveRange(5, 6));
          if (system != BathSystemPreference.none &&
              phase == HotwaterSessionPhase.uncertain &&
              task == RuntimeTaskState.failure) {
            expect(copy.title, '设备结果待定');
          }
          if (system == BathSystemPreference.shower798 &&
              phase == HotwaterSessionPhase.active &&
              task == RuntimeTaskState.success) {
            expect(copy.title, '启动请求确认');
          }
        }
      }
    }
  });
  testWidgets('long failure does not move controls or resize the card',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(
        tester, stateFor(RuntimeTaskState.idle, message: '热水待启动'), 360, 1);
    final before = tester.getSize(find.byType(HotWaterCard));
    final buttonY = tester.getTopLeft(find.text('启动热水')).dy;
    await mount(
        tester, stateFor(RuntimeTaskState.failure, message: longError), 360, 1);
    expect(tester.getSize(find.byType(HotWaterCard)), before);
    expect(tester.getTopLeft(find.text('启动热水')).dy, buttonY);
  });
  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('stable status card width=$width scale=$scale',
          (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Size? size;
        double? buttonY;
        for (final state in [
          stateFor(RuntimeTaskState.idle, message: '热水待启动'),
          stateFor(RuntimeTaskState.loading, message: '正在启动热水'),
          stateFor(RuntimeTaskState.loading, message: '正在关闭热水', stopping: true),
          stateFor(RuntimeTaskState.failure, message: longError),
          stateFor(RuntimeTaskState.permissionRequired, message: longError),
          stateFor(RuntimeTaskState.loginRequired,
              message: longError, stopping: true),
          stateFor(RuntimeTaskState.unavailable, message: longError),
          stateFor(RuntimeTaskState.success,
              message: '停止请求已确认，请核对设备', stopping: true),
        ]) {
          await mount(tester, state, width, scale);
          if (const bool.fromEnvironment('CAPTURE_HOTWATER')) {
            if (width == 360 && scale == 1) {
              final context = tester.element(find.byType(HotWaterCard));
              final images =
                  tester.widgetList<Image>(find.byType(Image)).toList();
              await tester.runAsync(() => Future.wait(
                  images.map((image) => precacheImage(image.image, context))));
              await tester.pumpAndSettle();
              for (final image
                  in tester.widgetList<RawImage>(find.byType(RawImage))) {
                expect(image.image, isNotNull);
              }
              await expectLater(
                  find.byKey(const ValueKey('capture-hotwater')),
                  matchesGoldenFile(
                      '../P_PLAN/evidence/hotwater-${state.hotwaterStart.state.name}-${state.hotwaterStop.state.name}.png'));
            }
          }
          final currentSize = tester.getSize(find.byType(HotWaterCard));
          size ??= currentSize;
          expect(currentSize, size);
          final y = tester.getTopLeft(find.text('启动热水')).dy;
          buttonY ??= y;
          expect(y, buttonY);
          final title = tester.widget<Text>(
              find.byKey(const ValueKey('hotwater-status-title')));
          expect(title.data!.runes.length, lessThanOrEqualTo(6));
          expect(title.maxLines, 1);
          final titleRender = tester.renderObject<RenderParagraph>(
              find.byKey(const ValueKey('hotwater-status-title')));
          expect(titleRender.didExceedMaxLines, isFalse);
          final note = tester.renderObject<RenderParagraph>(
              find.byKey(const ValueKey('hotwater-status-note')));
          expect(note.maxLines, 1);
          expect(note.didExceedMaxLines, isFalse);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
  testWidgets(
      'long start and stop messages remain accessible in scrollable details',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const stopError = '关闭结果也尚未确认，请核对原账号和设备，不要清除本地会话。';
    var starts = 0, stops = 0, changes = 0;
    final state = stateFor(RuntimeTaskState.failure, message: longError)
        .copyWith(
            hotwaterStop: const RuntimeActionStatus(
                state: RuntimeTaskState.failure, message: stopError));
    await mount(tester, state, 320, 2,
        start: () => starts++, stop: () => stops++, change: () => changes++);
    await tester
        .ensureVisible(find.byKey(const ValueKey('hotwater-status-details')));
    await tester.tap(find.byKey(const ValueKey('hotwater-status-details')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(longError), findsOneWidget);
    expect(find.text(stopError), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(SingleChildScrollView)),
        findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    for (final text in ['启动热水', '停止热水', '住理生活']) {
      await tester.ensureVisible(find.text(text));
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }
    expect([starts, stops, changes], [1, 1, 1]);
  });
}
