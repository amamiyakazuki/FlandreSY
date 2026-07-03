// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppTheme, AppColors.background, AppTypography.textTheme.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../data/account_session_repository.dart';
import '../data/adapters/hotwater_adapter.dart';
import '../data/adapters/shower798_adapter.dart';
import '../data/adapters/ujing_adapter.dart';
import '../data/app_bootstrap.dart';
import '../data/history_repository.dart';
import '../data/local_device_repository.dart';
import '../data/secure_session_repository.dart';
import '../data/settings_repository.dart';
import '../runtime/fake_shui_runtime.dart';
import '../runtime/live_clock.dart';
import '../shell/shui_shell.dart';

class FlandreApp extends StatelessWidget {
  const FlandreApp({
    this.settings,
    this.sessions,
    this.devices,
    this.history,
    this.secure,
    this.clock,
    this.ujing,
    this.hotwater,
    this.shower798,
    this.initial,
    super.key,
  });

  /// 可选注入的设置持久化（测试传内存实现，保持 golden 确定性）。
  final SettingsRepository? settings;

  /// 可选注入的账号 session 持久化（测试传内存实现）。
  final AccountSessionRepository? sessions;

  /// 可选注入的本地设备持久化（测试/golden 传内存实现预置设备）。
  final LocalDeviceRepository? devices;

  /// 可选注入的热水历史持久化（测试传内存实现）。
  final HistoryRepository? history;

  /// 可选注入的敏感凭证持久化（测试传内存实现）。默认生产用 flutter_secure_storage。
  final SecureSessionRepository? secure;

  /// 可选注入的时间源（测试传 FixedLiveClock）。
  final LiveClock? clock;

  /// 可选注入的 Ujing 适配器（默认 FakeUjingAdapter；真机验证注入 UjingHttpAdapter）。
  final IUjingAdapter? ujing;

  /// 可选注入的 Zhuli 热水适配器（默认 FakeHotwaterAdapter；真机验证注入 RealZhuliAdapter）。
  final IHotwaterAdapter? hotwater;

  /// 可选注入的 798 洗浴适配器（默认 FakeShower798Adapter；真机验证注入 RealShower798Adapter）。
  final IShower798Adapter? shower798;

  /// 可选预加载的持久化快照（main() 已 await 读出，消除首帧闪烁）。
  final PersistedSnapshot? initial;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '芙兰水衣',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme.copyWith(
        scaffoldBackgroundColor: AppColors.background,
        textTheme: AppTypography.textTheme.apply(
          bodyColor: AppColors.deepText,
          displayColor: AppColors.deepText,
        ),
      ),
      home: ShuiRuntimeScope(
        settings: settings,
        sessions: sessions,
        devices: devices,
        history: history,
        secure: secure,
        clock: clock,
        ujing: ujing,
        hotwater: hotwater,
        shower798: shower798,
        initial: initial,
        child: const ShuiShell(),
      ),
    );
  }
}
