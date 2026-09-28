import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/hotwater/hotwater_detail_screen.dart';
import 'package:flandresy/src/runtime/fake_shui_runtime.dart';
import 'package:flandresy/src/runtime/hotwater_state.dart';
import 'package:flandresy/src/runtime/models/hotwater_history.dart';

void main() {
  const message = '启动指令已发送，但结果待确认。请查看设备实际供水情况，不要根据历史记录判断设备已经停止。';
  const device = '超长设备编号ABCDEFGHIJKLMN0123456789浴室设备';
  const status = '历史记录状态较长时也必须完整显示不能被省略';
  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('detail width=$width scale=$scale readable and tappable',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var starts = 0;
        var stops = 0;
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: HotwaterDetailScreen(
            state: const ShuiHomeState(
              bathSystemPreference: BathSystemPreference.zhuli,
              hotwater: HotwaterState(
                start: RuntimeActionStatus(
                    state: RuntimeTaskState.loading, message: message),
                stop: RuntimeActionStatus(
                    state: RuntimeTaskState.failure,
                    message: '结束热水失败，请检查蓝牙连接后重试。'),
                historyStatus:
                    RuntimeActionStatus(state: RuntimeTaskState.success),
                history: [
                  HotwaterHistoryUi(
                      time: '2026-09-21 12:34:56',
                      deviceId: device,
                      amount: '¥12345.67',
                      status: status,
                      orderId: '1')
                ],
              ),
            ),
            onBack: () {},
            onStart: () => starts++,
            onStop: () => stops++,
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final startRect = tester.getRect(find.text('启动热水'));
        final stopRect = tester.getRect(find.text('停止热水'));
        if (scale == 1) {
          expect(startRect.top, stopRect.top);
        }
        if (scale == 2 && width == 320) {
          expect(stopRect.top, greaterThan(startRect.bottom));
        }
        for (final label in ['启动热水', '停止热水']) {
          await tester.ensureVisible(find.text(label));
          await tester.pumpAndSettle();
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }
        expect(starts, 2);
        expect(stops, 2);
        for (final text in [
          message,
          '设备 $device',
          status,
          '¥12345.67',
          '住理热水历史'
        ]) {
          final finder = find.text(text);
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          final paragraph = tester.renderObject<RenderParagraph>(finder);
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(paragraph.maxLines, isNull);
          final rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
