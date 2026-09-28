import 'package:flandresy/src/home/cards/ongoing_card.dart';
import 'package:flandresy/src/runtime/runtime_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _tasks = [
  HomeTaskUi(
      target: HomeTaskTarget.hotwater,
      title: '热水使用中',
      extra: '已开启',
      asset: 'shui_reshui.png'),
  HomeTaskUi(
      target: HomeTaskTarget.washer,
      title: '洗衣进行中',
      extra: '剩余时间',
      asset: 'shui_yifu.png'),
  HomeTaskUi(
      target: HomeTaskTarget.drinking,
      title: '接水进行中',
      extra: '接水中',
      asset: 'shui_jieshui.png'),
];

Future<void> _show(WidgetTester tester, List<HomeTaskUi> tasks, double width,
    {double scale = 1}) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: SingleChildScrollView(
              child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
        width: width,
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: const ValueKey('capture-ongoing'),
            child: OngoingCard(tasks: tasks),
          ),
        )),
  )))));
  // Asset decoding runs outside fake time; settling layout alone can capture
  // blank icon slots. Wait for the providers actually displayed in this tree.
  final context = tester.element(find.byType(OngoingCard));
  final images = tester.widgetList<Image>(find.byType(Image)).toList();
  await tester.runAsync(() async {
    await Future.wait(
        images.map((image) => precacheImage(image.image, context)));
  });
  await tester.pumpAndSettle();
  for (final image in tester.widgetList<RawImage>(find.byType(RawImage))) {
    expect(image.image, isNotNull,
        reason: 'Evidence must contain decoded icons');
  }
}

void main() {
  testWidgets('capture ongoing card layout evidence', (tester) async {
    for (var count = 1; count <= 3; count++) {
      await _show(tester, _tasks.sublist(3 - count), 328);
      await expectLater(find.byKey(const ValueKey('capture-ongoing')),
          matchesGoldenFile('evidence/ongoing-$count.png'));
    }
  }, skip: !const bool.fromEnvironment('CAPTURE_LAYOUT'));

  for (final width in [288.0, 328.0, 380.0]) {
    testWidgets('fixed thirds and 4dp gaps at $width', (tester) async {
      await _show(tester, _tasks, width);
      final baseline = tester.getSize(find.byType(OngoingCard)).height;
      final first = tester.getRect(find.byType(RunningStatusCard).at(0));
      // Existing content + padding + 2dp border; no additional vertical spacing.
      expect(first.height, closeTo(92, .3));
      final row =
          tester.getRect(find.byKey(const ValueKey('running-task-row')));
      expect(first.width, closeTo((row.width - 8) / 3, .01));
      expect(first.left, closeTo(row.left, .01));
      expect(first.top, closeTo(row.top, .01));
      for (var i = 1; i < 3; i++) {
        final previous =
            tester.getRect(find.byType(RunningStatusCard).at(i - 1));
        final current = tester.getRect(find.byType(RunningStatusCard).at(i));
        expect(current.width, closeTo(first.width, .01));
        expect(current.height, closeTo(first.height, .01));
        expect(current.top, closeTo(first.top, .01));
        expect(current.left - previous.right, closeTo(4, .01));
      }
      expect(tester.getRect(find.byType(RunningStatusCard).last).right,
          closeTo(row.right, .01));
      for (final subset in [
        _tasks.sublist(1),
        [_tasks.last],
        [_tasks.first, _tasks.last]
      ]) {
        await _show(tester, subset, width);
        final current = tester.getRect(find.byType(RunningStatusCard).first);
        expect(current.left, closeTo(first.left, .01));
        expect(current.width, closeTo(first.width, .01));
        expect(tester.getSize(find.byType(OngoingCard)).height,
            closeTo(baseline, .01));
        if (subset.length == 2) {
          final second = tester.getRect(find.byType(RunningStatusCard).at(1));
          expect(second.left - current.right, closeTo(4, .01));
        }
        expect(tester.takeException(), isNull);
      }
      await _show(tester, [], width);
      expect(find.text('无任务'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('long labels have equal heights after task replacements settle',
      (tester) async {
    const long = HomeTaskUi(
        target: HomeTaskTarget.washer,
        title: '洗衣订单状态较长等待更新',
        extra: '旧订单状态更新中',
        asset: 'shui_yifu.png');
    await _show(tester, [_tasks.first, long, _tasks.last], 288, scale: 2);
    final cards = find.byType(RunningStatusCard);
    final height = tester.getSize(cards.first).height;
    final first = tester.getRect(cards.first);
    for (var i = 1; i < 3; i++) {
      expect(tester.getSize(cards.at(i)).height, height);
      final rect = tester.getRect(cards.at(i));
      final previous = tester.getRect(cards.at(i - 1));
      expect(rect.width, closeTo(first.width, .01));
      expect(rect.top, closeTo(first.top, .01));
      expect(rect.left - previous.right, closeTo(4, .01));
    }
    expect(tester.takeException(), isNull);
    await _show(tester, [long], 288, scale: 2);
    await _show(tester, _tasks, 288);
    expect(find.byType(RunningStatusCard), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
