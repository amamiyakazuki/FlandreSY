import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/profile/account_detail_screen.dart';
import 'package:flandresy/src/runtime/fake_shui_runtime.dart';
import 'package:flandresy/src/runtime/account_state.dart';
import 'package:flandresy/src/runtime/models/account_session.dart';

Widget _page(AccountKind kind,
        {ShuiHomeState state = const ShuiHomeState(),
        ValueChanged<AccountKind>? check,
        ValueChanged<AccountKind>? logout,
        VoidCallback? captcha,
        VoidCallback? refreshDevices,
        VoidCallback? legacyCheck,
        int? accountGeneration}) =>
    MaterialApp(
        home: AccountDetailScreen(
      key: const ValueKey('account-page'),
      kind: kind,
      accountGeneration: accountGeneration,
      state: state,
      nowMillis: 0,
      onBack: () {},
      onCheckAccount: check,
      onLogout: logout,
      onLoginZhuli: (_, __) {},
      onBindDeviceCode: (_) {},
      onCheckZhuli: legacyCheck ?? () {},
      onRequestUjingCaptcha: (_) {},
      onLoginUjing: (_, __) {},
      onCheckUjing: legacyCheck ?? () {},
      onRequestShower798Captcha: captcha ?? () {},
      onSendShower798Sms: (_, __) {},
      onLoginShower798: (_, __) {},
      onAddShower798Device: (_) {},
      onRefreshShower798Devices: refreshDevices ?? () {},
      onSelectShower798Device: (_) {},
      onSetDefaultSystem: (_) {},
    ));

void main() {
  testWidgets(
      'same service account replacement or new login epoch invalidates logout confirmation',
      (tester) async {
    final logouts = <AccountKind>[];
    ShuiHomeState account(AccountKind kind, String phone) => ShuiHomeState(
            account: AccountState(
          zhuli: ZhuliSession(phone: phone),
          ujingAccount: UjingAccountUi(
              mobile: phone, userId: phone, serviceSubjectId: 's'),
          shower798Account:
              Shower798AccountUi(mobile: phone, uid: phone, eid: 'e'),
        ));
    for (final kind in AccountKind.values) {
      for (final sameAccount in [false, true]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(_page(kind,
            state: account(kind, 'account-a'),
            check: (_) {},
            logout: logouts.add,
            accountGeneration: 1));
        await tester.pumpAndSettle();
        await tester.tap(find.text('退出本机登录'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(_page(kind,
            state: account(kind, sameAccount ? 'account-a' : 'account-b'),
            check: (_) {},
            logout: logouts.add,
            accountGeneration: sameAccount ? 2 : 1));
        await tester.pumpAndSettle();
        await tester.tap(find.text('确认退出'));
        await tester.pumpAndSettle();
        expect(logouts, isEmpty);
        expect(find.text('账号状态已变化，请重新确认退出'), findsOneWidget);
      }
    }
  });
  testWidgets(
      'entry checks once per kind or re-entry, never per rebuild or elapsed time',
      (tester) async {
    final checks = <AccountKind>[];
    for (final kind in AccountKind.values) {
      await tester.pumpWidget(_page(kind, check: checks.add));
      await tester.pumpAndSettle();
      final expected = checks.length;
      expect(checks.last, kind);
      await tester.pumpWidget(_page(kind, check: checks.add));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 1));
      expect(checks.length, expected);
      await tester.tap(find.text('检测账号状态'));
      await tester.pump();
      expect(checks.length, expected + 1);
    }
    expect(checks.length, 6);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_page(AccountKind.shower798, check: checks.add));
    await tester.pumpAndSettle();
    expect(checks.length, 7);
  });

  testWidgets(
      'all services keep logout available with stale busy or expired login; cancel does nothing',
      (tester) async {
    final logouts = <AccountKind>[];
    for (final status in [
      RuntimeTaskState.loading,
      RuntimeTaskState.loginRequired
    ]) {
      final action = RuntimeActionStatus(state: status, message: '旧登录状态');
      final state = ShuiHomeState(
          account: AccountState(
              hotwaterLogin: action,
              washerLogin: action,
              shower798Login: action));
      for (final kind in AccountKind.values) {
        await tester.pumpWidget(
            _page(kind, state: state, check: (_) {}, logout: logouts.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('退出本机登录'));
        await tester.pumpAndSettle();
        expect(find.textContaining('保留已有订单和设备记录'), findsOneWidget);
        expect(find.textContaining('不会关闭真实设备'), findsOneWidget);
        final count = logouts.length;
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(logouts.length, count);
        await tester.tap(find.text('退出本机登录'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('确认退出'));
        await tester.pumpAndSettle();
        expect(logouts.last, kind);
        expect(logouts.length, count + 1);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('confirmation for a previous service cannot log out the new kind',
      (tester) async {
    final logouts = <AccountKind>[];
    await tester.pumpWidget(
        _page(AccountKind.zhuli, check: (_) {}, logout: logouts.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出本机登录'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
        _page(AccountKind.ujing, check: (_) {}, logout: logouts.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认退出'));
    await tester.pumpAndSettle();
    expect(logouts, isEmpty);
  });

  testWidgets('dedicated availability banner does not depend on login status',
      (tester) async {
    for (final kind in AccountKind.values) {
      final state = ShuiHomeState(
          account: AccountState(availability: {
        kind: const RuntimeActionStatus(
            state: RuntimeTaskState.failure, message: '网络失败，尚不能确认账号可用性')
      }));
      await tester
          .pumpWidget(_page(kind, state: state, check: (_) {}, logout: (_) {}));
      await tester.pumpAndSettle();
      expect(find.text('网络失败，尚不能确认账号可用性'), findsOneWidget);
      expect(find.text('检测账号状态'), findsOneWidget);
      expect(find.text('退出本机登录'), findsOneWidget);
      expect(find.text('检查账号状态'), findsNothing);
      expect(find.text('查看状态'), findsNothing);
    }
  });

  testWidgets(
      '798 entry avoids duplicate device query and skips captcha while logged in',
      (tester) async {
    var captcha = 0, devices = 0, checks = 0;
    const logged = ShuiHomeState(
        account: AccountState(
            shower798Account:
                Shower798AccountUi(mobile: '13800000001', uid: 'u', eid: 'e')));
    await tester.pumpWidget(_page(AccountKind.shower798,
        state: logged,
        check: (_) => checks++,
        captcha: () => captcha++,
        refreshDevices: () => devices++));
    await tester.pumpAndSettle();
    expect(checks, 1);
    expect(captcha, 0);
    expect(devices, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_page(AccountKind.shower798,
        check: (_) => checks++,
        captcha: () => captcha++,
        refreshDevices: () => devices++));
    await tester.pumpAndSettle();
    expect(checks, 2);
    expect(captcha, 1);
    expect(devices, 0);
  });

  testWidgets(
      'optional callbacks retain old construction without automatic checks',
      (tester) async {
    var legacy = 0;
    await tester
        .pumpWidget(_page(AccountKind.ujing, legacyCheck: () => legacy++));
    await tester.pumpAndSettle();
    expect(legacy, 0);
    expect(find.text('检测账号状态'), findsNothing);
    expect(find.text('退出本机登录'), findsNothing);
    await tester.ensureVisible(find.text('查看状态'));
    await tester.tap(find.text('查看状态'));
    await tester.pump();
    expect(legacy, 1);
  });
}
