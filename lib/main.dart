// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppTheme, AppColors.background, AppTypography.textTheme, AppCustomTokens adaptive shell tokens.

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'src/app/flandre_app.dart';
import 'src/data/adapters/alipay_payment_launcher.dart';
import 'src/data/adapters/flutter_blue_plus_ble_transport.dart';
import 'src/data/adapters/hotwater_adapter.dart';
import 'src/data/adapters/io_shower798_transport.dart';
import 'src/data/adapters/io_zhuli_transport.dart';
import 'src/data/adapters/real_shower798_adapter.dart';
import 'src/data/adapters/real_zhuli_adapter.dart';
import 'src/data/adapters/shower798_adapter.dart';
import 'src/data/adapters/ujing_adapter.dart';
import 'src/data/adapters/ujing_http_adapter.dart';
import 'src/data/app_bootstrap.dart';
import 'src/data/flutter_secure_session_repository.dart';
import 'src/data/secure_session_repository.dart';
import 'src/data/shared_prefs_account_session_repository.dart';
import 'src/data/shared_prefs_history_repository.dart';
import 'src/data/shared_prefs_diagnostic_log_repository.dart';
import 'src/data/shared_prefs_local_device_repository.dart';
import 'src/data/shared_prefs_settings_repository.dart';
import 'src/data/shared_prefs_water_order_repository.dart';
import 'src/more/version_check.dart' show kCurrentAppVersion;
import 'src/runtime/diagnostic_log.dart';
import 'src/runtime/live_clock.dart';

/// 开发用「强制模拟后端」覆盖（Phase 0）。默认 false。
/// 现在**默认真实后端**：正常构建/运行即真实登录/网络/支付/BLE。
/// 想要无账号/设备的纯 Fake 演示或 golden 环境，有两条路：
///  1. 运行时：MoreOptions →「使用模拟后端」开关（持久化，重启生效）。
///  2. 开发期：`flutter run --dart-define=SIMULATE_BACKEND=true`（不落盘，仅本次进程）。
/// 二者任一为真即走 Fake + InMemory。真实模式下支付宝 SDK 那一跳由 RealPaymentLauncher
/// 经原生 platform channel（Android 已接通）；BLE 经 FlutterBluePlusBleTransport。
const bool _forceSimulateBackend = bool.fromEnvironment('SIMULATE_BACKEND');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // P1/P2：启动前预加载持久化快照（偏好 + 账号 session + 模拟后端开关），作为初始 state 注入，
  // 消除首帧默认值闪烁（Grok P1 Major 1）。失败回退默认。
  final settings = SharedPrefsSettingsRepository();
  final sessions = SharedPrefsAccountSessionRepository();
  final devices = SharedPrefsLocalDeviceRepository();
  final history = SharedPrefsHistoryRepository();
  final water = SharedPrefsWaterOrderRepository();
  final initial =
      await AppBootstrap.load(settings, sessions, devices, history, water);

  // M-REAL 检查版本：真实 App 版本号（PackageInfo.version）。读失败回退常量兜底。
  String appVersion;
  try {
    appVersion = (await PackageInfo.fromPlatform()).version;
  } catch (_) {
    appVersion = kCurrentAppVersion;
  }

  // M-REAL 日志与诊断：持久化环形日志器。真实 adapter 埋点写入，日志页读；
  // FlutterError 也灌进来（对齐 legacy「后台组件结果也记录」）。
  final diagnosticLog = DiagnosticLog(
    repo: SharedPrefsDiagnosticLogRepository(),
    clock: const SystemLiveClock(),
  );
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    diagnosticLog.log('flutter-error', details.exceptionAsString());
    previousOnError?.call(details);
  };

  // Phase 0：默认真实后端。持久化开关或 dev define 任一为真 → 全 Fake + InMemory。
  // adapter 在启动时一次性构造，故开关改动需重启才生效（MoreOptions 会提示「重启后生效」）。
  final bool useSimulated =
      _forceSimulateBackend || initial.useSimulatedBackend;
  final bool useReal = !useSimulated;

  // PTOK：敏感凭证仓库。模拟模式 null → runtime 用 InMemory（无 token）；
  // 真实模式用 flutter_secure_storage，并在建 adapter 前读出已持久化凭证注入回去（重启免重登）。
  final SecureSessionRepository? secure =
      useReal ? FlutterSecureSessionRepository() : null;
  final String? ujingToken = useReal ? await secure!.loadUjingToken() : null;
  final ZhuliSessionData? zhuliSession =
      useReal ? await secure!.loadZhuliSession() : null;
  final String? shower798Token =
      useReal ? await secure!.loadShower798Token() : null;

  // 真实模式注入真实 HTTP adapter（+ RealPaymentLauncher，支付宝 SDK 原生那一跳由用户真机验证）；
  // 恢复 token 注入。模拟模式 null → runtime 默认 FakeUjingAdapter。
  final IUjingAdapter? ujing = useReal
      ? UjingHttpAdapter(
          launcher: const RealPaymentLauncher(),
          token: ujingToken,
          log: diagnosticLog.sinkFor('ujing'),
        )
      : null;
  // 真实模式注入 RealZhuliAdapter（签名 HTTP + BLE）。BLE 那几步经 FlutterBluePlusBleTransport
  // （真实 GATT），由用户真机授权 + 靠近设备验证。模拟模式 null → FakeHotwaterAdapter。
  final IHotwaterAdapter? hotwater = useReal
      ? RealZhuliAdapter(
          transport: IoZhuliTransport(),
          ble: const FlutterBluePlusBleTransport(),
          session: zhuliSession,
          log: diagnosticLog.sinkFor('hotwater'),
        )
      : null;
  // 真实模式注入 RealShower798Adapter（纯 token HTTP）；恢复 token 注入。
  // 模拟模式 null → FakeShower798Adapter。
  final IShower798Adapter? shower798 = useReal
      ? RealShower798Adapter(
          transport: IoShower798Transport(),
          token: shower798Token,
          log: diagnosticLog.sinkFor('shower798'),
        )
      : null;
  runApp(
    FlandreApp(
      settings: settings,
      sessions: sessions,
      devices: devices,
      history: history,
      water: water,
      secure: secure,
      ujing: ujing,
      hotwater: hotwater,
      shower798: shower798,
      diagnosticLog: diagnosticLog,
      appVersion: appVersion,
      initial: initial,
    ),
  );
}
