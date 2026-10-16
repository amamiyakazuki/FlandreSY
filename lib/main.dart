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
import 'src/data/legacy_data_migration.dart';
import 'src/data/flutter_secure_session_repository.dart';
import 'src/data/secure_session_repository.dart';
import 'src/data/shared_prefs_account_session_repository.dart';
import 'src/data/shared_prefs_history_repository.dart';
import 'src/data/shared_prefs_diagnostic_log_repository.dart';
import 'src/data/shared_prefs_local_device_repository.dart';
import 'src/data/shared_prefs_settings_repository.dart';
import 'src/data/shared_prefs_water_order_repository.dart';
import 'src/data/shared_prefs_washer_history_repository.dart';
import 'src/more/version_check.dart' show kCurrentAppVersion;
import 'src/runtime/diagnostic_log.dart';
import 'src/runtime/live_clock.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 消除首帧默认值闪烁（Grok P1 Major 1）。失败回退默认。
  final settings = SharedPrefsSettingsRepository();
  final sessions = SharedPrefsAccountSessionRepository();
  final devices = SharedPrefsLocalDeviceRepository();
  final history = SharedPrefsHistoryRepository();
  final water = SharedPrefsWaterOrderRepository();
  final washerHistory = SharedPrefsWasherHistoryRepository();
  final migration = LegacyDataMigration(SharedPrefsLegacyMigrationStore());
  final initial = await AppBootstrap.load(
    settings,
    sessions,
    devices,
    history,
    water,
    washerHistory,
    migration: migration,
  );

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

  final SecureSessionRepository secure = FlutterSecureSessionRepository();
  Future<T?> loadCredential<T>(
      String service, Future<T?> Function() load) async {
    try {
      return await load();
    } catch (error) {
      diagnosticLog.log(
          'auth', '$service 凭据读取失败 type=${error.runtimeType}，需重新登录');
      return null;
    }
  }

  final String? ujingToken = !migration.needsLogin('ujing')
      ? await loadCredential('U净', secure.loadUjingToken)
      : null;
  final ZhuliSessionData? zhuliSession = !migration.needsLogin('zhuli')
      ? await loadCredential('住理', secure.loadZhuliSession)
      : null;
  final String? shower798Token = !migration.needsLogin('shower798')
      ? await loadCredential('798', secure.loadShower798Token)
      : null;

  // 真实模式注入真实 HTTP adapter（+ RealPaymentLauncher，支付宝 SDK 原生那一跳由用户真机验证）；
  final IUjingAdapter ujing = UjingHttpAdapter(
    launcher: const RealPaymentLauncher(),
    token: ujingToken,
    log: diagnosticLog.sinkFor('ujing'),
  );
  // 真实模式注入 RealZhuliAdapter（签名 HTTP + BLE）。BLE 那几步经 FlutterBluePlusBleTransport
  final IHotwaterAdapter hotwater = RealZhuliAdapter(
    transport: IoZhuliTransport(),
    ble: const FlutterBluePlusBleTransport(),
    session: zhuliSession,
    log: diagnosticLog.sinkFor('hotwater'),
  );
  // 真实模式注入 RealShower798Adapter（纯 token HTTP）；恢复 token 注入。
  final IShower798Adapter shower798 = RealShower798Adapter(
    transport: IoShower798Transport(),
    token: shower798Token,
    log: diagnosticLog.sinkFor('shower798'),
  );
  runApp(
    FlandreApp(
      settings: settings,
      sessions: sessions,
      devices: devices,
      history: history,
      water: water,
      washerHistory: washerHistory,
      secure: secure,
      ujing: ujing,
      hotwater: hotwater,
      shower798: shower798,
      diagnosticLog: diagnosticLog,
      appVersion: appVersion,
      initial: initial,
      migration: migration,
    ),
  );
}
