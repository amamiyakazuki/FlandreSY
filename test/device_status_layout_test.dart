import 'package:flandresy/src/devices/device_list_item.dart';
import 'package:flandresy/src/profile/shower798_device_tile.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';
import 'package:flandresy/src/runtime/models/local_device.dart';
import 'package:flandresy/src/widgets/device_status_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const running = '此设备正在运行中，请使用其他设备';
const washer = LocalDeviceShortcut(
  id: 'washer-test',
  customName: '洗衣机-5008913',
  deviceNo: '5008913',
  deviceType: LocalDeviceType.washer,
  storeName: '扫码添加',
  statusConfirmed: true,
  statusCheckedAt: '11:57',
);

Future<void> showCard(WidgetTester tester, Widget card,
    {double width = 360, double scale = 1}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: card,
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

DeviceListItem item(LocalDeviceShortcut device,
        {VoidCallback? open, VoidCallback? menu}) =>
    DeviceListItem(
      device: device,
      displayName: device.customName,
      index: 0,
      onOpen: open ?? () {},
      onMenu: menu ?? () {},
    );

void main() {
  test('compact display only recognizes exact running messages', () {
    expect(compactDeviceStatus(running), '运行中');
    expect(compactDeviceStatus('$running。'), '运行中');
    expect(compactDeviceStatus('未运行'), '未运行');
    expect(compactDeviceStatus('设备未运行，请联系管理员检查'), '查看状态');
    expect(compactDeviceStatus('运行失败，请联系管理员检查'), '查看状态');
    expect(compactDeviceStatus('可下单'), '可下单');
    expect(compactDeviceStatus('未知\n状态'), '查看状态');
    expect(compactDeviceStatus(null), '状态未知');
  });

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('device card status stays in one row at $width / $scale',
          (tester) async {
        Rect? baseline;
        Rect? nameBounds;
        Rect? numberBounds;
        for (final device in [
          washer.copyWith(lastStatus: '可下单'),
          washer.copyWith(lastStatus: running),
          washer.copyWith(lastStatus: '未知设备状态，请联系管理员检查。' * 15),
          washer.copyWith(lastStatus: running, statusQueryFailed: true),
          washer.copyWith(lastStatus: running, statusConfirmed: false),
        ]) {
          await showCard(tester, item(device), width: width, scale: scale);
          final rect = tester.getRect(find.byType(DeviceListItem));
          final name = tester.getRect(find.text(washer.customName));
          final number = tester.getRect(find.text('设备号：5008913'));
          baseline ??= rect;
          nameBounds ??= name;
          numberBounds ??= number;
          expect(rect, baseline);
          expect(name, nameBounds);
          expect(number, numberBounds);
          final statusText = find.descendant(
              of: find.byType(DeviceStatusLabel), matching: find.byType(Text));
          final paragraph = tester.renderObject<RenderParagraph>(statusText);
          expect(paragraph.didExceedMaxLines, isFalse, reason: '短状态本身必须完整可见');
          if (scale == 1) {
            expect(
                tester
                    .renderObject<RenderParagraph>(find.text(washer.customName))
                    .didExceedMaxLines,
                isFalse);
            expect(
                tester
                    .renderObject<RenderParagraph>(find.text('设备号：5008913'))
                    .didExceedMaxLines,
                isFalse);
          }
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('full details retain freshness and do not open the device',
      (tester) async {
    var opens = 0;
    var menus = 0;
    for (final entry in [
      (washer.copyWith(lastStatus: running), '运行中', '查询于 11:57'),
      (
        washer.copyWith(lastStatus: running, statusQueryFailed: true),
        '查询失败',
        '本次查询失败；上次结果'
      ),
      (
        washer.copyWith(lastStatus: running, statusConfirmed: false),
        '待核对',
        '未核对'
      ),
    ]) {
      await showCard(
          tester, item(entry.$1, open: () => opens++, menu: () => menus++));
      expect(find.text(running), findsNothing);
      await tester.tap(find.text(entry.$2));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      final details =
          tester.widget<SelectableText>(find.byType(SelectableText)).data!;
      expect(details, contains(running));
      expect(details, contains(entry.$3));
      expect(opens, 0);
      expect(menus, 0);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(washer.customName));
    await tester.pumpAndSettle();
    expect(opens, 1);
    await tester.tap(find.byKey(const ValueKey('device-dot-0')));
    await tester.pumpAndSettle();
    expect(menus, 1);
  });

  testWidgets('798 long status cannot squeeze name; selection still works',
      (tester) async {
    var selections = 0;
    Rect? baseline;
    for (final status in ['空闲', running, '停止请求已确认', '状态无法确认，请联系管理员核对设备']) {
      await showCard(
          tester,
          Shower798DeviceTile(
              device: Shower798DeviceUi(
                  id: '79812345',
                  name: '浴室设备-79812345',
                  lastStatus: status,
                  statusConfirmed: true),
              isCurrent: false,
              onSelect: () => selections++),
          width: 320,
          scale: 2);
      final rect = tester.getRect(find.byType(Shower798DeviceTile));
      baseline ??= rect;
      expect(rect, baseline);
      expect(
          tester
              .renderObject<RenderParagraph>(find.text('浴室设备-79812345'))
              .didExceedMaxLines,
          isFalse);
      await tester.tap(find.byType(DeviceStatusLabel));
      await tester.pumpAndSettle();
      expect(tester.widget<SelectableText>(find.byType(SelectableText)).data,
          contains(status));
      expect(selections, 0);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('浴室设备-79812345'));
    await tester.pumpAndSettle();
    expect(selections, 1);
  });

  testWidgets('cached 798 state is not presented as current, including details',
      (tester) async {
    await showCard(
        tester,
        const Shower798DeviceTile(
          device: Shower798DeviceUi(id: '798', name: '浴室设备', lastStatus: '空闲'),
          isCurrent: true,
          onSelect: null,
        ));
    await tester.tap(find.text('当前设备'));
    await tester.pumpAndSettle();
    expect(tester.widget<SelectableText>(find.byType(SelectableText)).data,
        contains('状态未查询'));
    expect(find.textContaining('空闲'), findsNothing);
  });

  testWidgets('device card preview contains all three compact states',
      (tester) async {
    await showCard(
        tester,
        RepaintBoundary(
          key: const ValueKey('device-preview'),
          child: Column(children: [
            item(washer.copyWith(lastStatus: '可下单')),
            const SizedBox(height: 8),
            item(washer.copyWith(lastStatus: running)),
            const SizedBox(height: 8),
            item(washer.copyWith(lastStatus: running, statusQueryFailed: true)),
          ]),
        ));
    expect(find.text('可下单'), findsOneWidget);
    expect(find.text('运行中'), findsOneWidget);
    expect(find.text('查询失败'), findsOneWidget);
    if (const bool.fromEnvironment('CAPTURE_LAYOUT')) {
      final context =
          tester.element(find.byKey(const ValueKey('device-preview')));
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      await tester.runAsync(() async {
        await Future.wait(
            images.map((image) => precacheImage(image.image, context)));
      });
      await tester.pumpAndSettle();
      await expectLater(find.byKey(const ValueKey('device-preview')),
          matchesGoldenFile('../P_PLAN/evidence/device-status-cards.png'));
    }
    expect(tester.takeException(), isNull);
  });
}
