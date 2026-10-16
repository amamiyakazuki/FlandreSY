// Runtime base: holds aggregate state + notify plumbing. Service actions live in mixins
// (home/devices/water) to keep each concern small and swappable for real adapters later.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/account_session_repository.dart';
import '../data/diagnostic_log_repository.dart';
import '../data/adapters/hotwater_adapter.dart';
import '../data/adapters/real_shower798_adapter.dart';
import '../data/adapters/real_zhuli_adapter.dart';
import '../data/adapters/shower798_adapter.dart';
import '../data/adapters/ujing_adapter.dart';
import '../data/adapters/ujing_http_adapter.dart';
import '../data/app_bootstrap.dart';
import '../data/legacy_data_migration.dart';
import '../data/history_repository.dart';
import '../data/local_device_repository.dart';
import '../data/device_import.dart';
import '../data/secure_session_repository.dart';
import '../data/settings_repository.dart';
import '../data/water_order_repository.dart';
import '../data/washer_history_repository.dart';
import '../more/version_check.dart' show kCurrentAppVersion;
import 'diagnostic_log.dart';
import 'live_clock.dart';
import 'models/hotwater_history.dart';
import 'models/account_session.dart';
import 'models/local_device.dart';
import 'models/water_order.dart';
import 'runtime_status.dart';
import 'hotwater_state.dart';
import 'shui_home_state.dart';

/// 需重登的服务标识（RELOG）。action 层捕获 authInvalid 后据此清对应服务的凭证 + 账号 state。
enum AuthService { ujing, zhuli, shower798 }

/// 运行时基类：持有聚合 [ShuiHomeState] + 通知管线 + 共享计时器。
/// 各服务的 action 以 mixin（on ShuiRuntimeBase）形式拆分，避免单文件聚合膨胀。
abstract class ShuiRuntimeBase extends ChangeNotifier {
  ShuiRuntimeBase({
    SettingsRepository? settings,
    AccountSessionRepository? sessions,
    LocalDeviceRepository? devices,
    HistoryRepository? history,
    WaterOrderRepository? water,
    WasherHistoryRepository? washerHistory,
    required this.secure,
    required this.migration,
    LiveClock? clock,
    required this.ujing,
    required this.hotwater,
    required this.shower798,
    DiagnosticLog? diagnosticLog,
    String? appVersion,
    PersistedSnapshot? initial,
  })  : settings = settings ?? InMemorySettingsRepository(),
        sessions = sessions ?? InMemoryAccountSessionRepository(),
        devices = devices ?? InMemoryLocalDeviceRepository(),
        history = history ?? InMemoryHistoryRepository(),
        water = water ?? InMemoryWaterOrderRepository(),
        washerHistoryRepository =
            washerHistory ?? InMemoryWasherHistoryRepository(),
        clock = clock ?? const SystemLiveClock(),
        diagnosticLog = diagnosticLog ??
            DiagnosticLog(repo: InMemoryDiagnosticLogRepository()),
        appVersion = appVersion ?? kCurrentAppVersion,
        _state = initial == null ? seedState() : _applySnapshot(initial) {
    // 恢复 deviceSeq / hotwaterOrderSeq 起点，避免新增 id 与已持久化数据撞号。
    deviceSeq = _maxDeviceSeq(_state.localDevices);
    hotwaterOrderSeq = _maxOrderSeq(_state.hotwater.history);
    ready = Future<void>.microtask(() async {
      await migration.prepare();
      if (initial == null) {
        await _restorePersisted();
      } else {
        applyRecoveryWarnings(initial);
      }
      reconcileRestoredAuth();
      await prepareLegacyRecords();
      await resumeHotwaterSession();
      await migrateLegacyUjingOrders();
      _washerPollingReady = true;
      syncWasherPolling();
      unawaited(resumeUjingOrders());
    });
  }

  final LegacyDataMigration migration;
  bool get legacyStorageBlocked =>
      migration.blocked || recoveryWarnings.isNotEmpty;
  Future<void> prepareLegacyRecords();
  Future<void> retryLegacyRecovery();
  Future<bool> verifyLegacyWater();
  Future<bool> verifyLegacyWasher();
  Future<bool> verifyLegacyHotwater();
  bool pendingLegacy(String kind, String id) =>
      legacyStorageBlocked || migration.isPending(kind, id);
  bool legacyServiceReady(String service) =>
      !legacyStorageBlocked && !migration.needsLogin(service);

  late final Future<void> ready;
  bool isDisposed = false;
  int hotwaterAuthEpoch = 0;
  int ujingAuthEpoch = 0;
  int ujingMutationCount = 0;
  int hotwaterAccountWriteCount = 0;
  int? _invalidatedUjingEpoch;
  String? _invalidatedUjingOwner;
  void beginUjingLoginEpoch() {
    _invalidatedUjingEpoch = null;
    _invalidatedUjingOwner = null;
    ujingAuthEpoch++;
    invalidateDeviceStatus();
  }

  bool canRetainUjingMutationResult(int epoch, String owner) =>
      isUjingRequestCurrent(epoch) ||
      (!isDisposed &&
          ujingMutationCount > 0 &&
          _invalidatedUjingEpoch == epoch &&
          _invalidatedUjingOwner == owner);
  bool ujingAuthChanging = false;
  bool hotwaterAuthChanging = false;
  bool ujingOrderStorageBlocked = false;
  String ujingLegacyOwnerKey = '';
  List<String> recoveryWarnings = [];

  void applyRecoveryWarnings(PersistedSnapshot snapshot) {
    recoveryWarnings = List.of(snapshot.recoveryWarnings);
    ujingOrderStorageBlocked = snapshot.ujingOrderStorageBlocked;
    for (final warning in recoveryWarnings) {
      diagnosticLog.log('storage', warning);
    }
  }

  String get ujingAccountKey => legacyServiceReady('ujing')
      ? state.ujingAccount?.mobile.trim() ?? ''
      : '';
  bool isUjingRequestCurrent(int epoch) =>
      !isDisposed && epoch == ujingAuthEpoch && !ujingAuthChanging;
  bool canAccessUjingOrder(String owner) =>
      !isDisposed &&
      !ujingAuthChanging &&
      legacyServiceReady('ujing') &&
      ujingAccountKey.isNotEmpty &&
      owner == ujingAccountKey;
  Future<void> resumeUjingOrders();
  Future<void> migrateLegacyUjingOrders();
  Future<void> migrateLegacyWasherOrders(String owner, int epoch);
  Future<void> resumeWasherOrders();
  Future<void> refreshCurrentWasherOrder();
  Future<void> checkAccountStatus(AccountKind kind);
  Future<void> logoutAccount(AccountKind kind);
  void resetAccountAvailability(AccountKind kind);
  bool get hotwaterOperationInFlight => false;

  /// 普通账号资料不能代替真实凭据；两种启动路径共同使用。
  void reconcileRestoredAuth() {
    final previous = state.ujingAccount?.mobile.trim() ?? '';
    if (previous.isNotEmpty) ujingLegacyOwnerKey = previous;
    const required = RuntimeActionStatus(
      state: RuntimeTaskState.loginRequired,
      message: '请重新登录',
    );
    if (ujing is UjingHttpAdapter &&
        (migration.needsLogin('ujing') ||
            (ujing as UjingHttpAdapter).lastToken?.isNotEmpty != true ||
            state.ujingAccount == null)) {
      (ujing as UjingHttpAdapter).invalidateAuth();
      emit(state.copyWith(clearUjingAccount: true, washerLogin: required));
    }
    if (hotwater is RealZhuliAdapter &&
        (migration.needsLogin('zhuli') ||
            !(hotwater as RealZhuliAdapter).hasCredentials ||
            !state.zhuli.isLoggedIn)) {
      (hotwater as RealZhuliAdapter).invalidateAuth();
      emit(state.copyWith(
          zhuli: state.zhuli.copyWith(phone: ''), hotwaterLogin: required));
    }
    if (shower798 is RealShower798Adapter &&
        (migration.needsLogin('shower798') ||
            (shower798 as RealShower798Adapter).lastToken?.isNotEmpty != true ||
            state.shower798Account == null)) {
      (shower798 as RealShower798Adapter).invalidateAuth();
      emit(state.copyWith(
          clearShower798Account: true, shower798Login: required));
    }
  }

  Future<void> resumeHotwaterSession();

  /// 清除当前热水会话的本地记录，不调用任何设备或服务端控制接口。
  /// [expected] 用于防止旧异步操作清理后来创建的新会话。
  Future<bool> clearHotwaterSessionLocally({
    HotwaterSession? expected,
    RuntimeTaskState resultState = RuntimeTaskState.success,
    String? message = '已清除本地热水状态',
    RuntimeActionStatus? stopStatus,
  }) async {
    final session = state.hotwater.session;
    if (isDisposed ||
        session == null ||
        pendingLegacy('hotwater', session.id)) {
      return false;
    }
    if (expected != null && expected.id != session.id) return false;

    try {
      await settings.saveHotwaterSession(null);
    } catch (_) {
      if (!isDisposed && state.hotwater.session?.id == session.id) {
        emit(state.copyWith(
          hotwater: state.hotwater.copyWith(
            start: const RuntimeActionStatus(
              state: RuntimeTaskState.failure,
              message: '本地热水状态清理失败，请重试',
            ),
          ),
        ));
      }
      return false;
    }
    if (isDisposed || state.hotwater.session?.id != session.id) return false;
    emit(state.copyWith(
      hotwater: state.hotwater.copyWith(
        running: false,
        clearSession: true,
        start: RuntimeActionStatus(state: resultState, message: message),
        stop: stopStatus ?? const RuntimeActionStatus(),
      ),
    ));
    // 先提交会话删除，避免设置写失败后留下无法关水的活动会话。
    try {
      await secure.saveHotwaterIsn(session.id, null);
    } catch (_) {
      diagnosticLog.sinkFor('hotwater')('本地热水凭据清理失败');
    }
    return true;
  }

  /// 设置持久化（P1）。runtime 只依赖接口，生产注入 shared_prefs，测试注入内存实现。
  final SettingsRepository settings;

  /// 账号 session 持久化（P2）。同 settings 解耦模式。
  final AccountSessionRepository sessions;

  /// 本地设备列表持久化（PDEV）。同 settings/sessions 解耦模式。
  final LocalDeviceRepository devices;

  /// 热水历史持久化（PHIST）。同 settings/sessions/devices 解耦模式。
  final HistoryRepository history;

  final WaterOrderRepository water;

  final WasherHistoryRepository washerHistoryRepository;

  /// 敏感凭证持久化（PTOK）。token/secretKey 加密存储；action 层登录成功后写入。
  /// 生产注入 flutter_secure_storage；测试显式提供内存仓库。
  final SecureSessionRepository secure;

  /// 时间源（W2 live 倒计时）。生产 SystemLiveClock，测试 FixedLiveClock。
  final LiveClock clock;

  /// Ujing 后端适配器（P4 A1）。生产默认注入 UjingHttpAdapter（Phase 0 翻真）；
  final IUjingAdapter ujing;

  /// Zhuli 热水适配器（P4 Z1）。生产默认注入 RealZhuliAdapter；
  final IHotwaterAdapter hotwater;

  /// 慧生活798 洗浴适配器（P4 S798）。生产默认注入 RealShower798Adapter；
  final IShower798Adapter shower798;

  final DiagnosticLog diagnosticLog;
  final String appVersion;

  ShuiHomeState _state;

  ShuiHomeState get state => _state;
  String? get zhuliControlUnavailableReason =>
      hotwater is HotwaterControlReadiness
          ? (hotwater as HotwaterControlReadiness).controlUnavailableReason
          : null;

  /// 账号和首页共用偏好写入入口，不依赖路由或动效。
  Future<void> setBathSystem(BathSystemPreference system) async {
    if (state.bathSystemPreference == system) return;
    emit(state.copyWith(bathSystemPreference: system));
    await settings.saveBathSystem(system);
  }

  /// 统一状态写入 + 通知。mixin 通过它更新状态，避免直接触碰私有字段。
  void emit(ShuiHomeState next) {
    if (isDisposed) return;
    if (next.zhuli.phone != _state.zhuli.phone) {
      next = next.copyWith(hotwaterHistoryStatus: const RuntimeActionStatus());
    }
    _state = next;
    syncWasherPolling();
    notifyListeners();
  }

  /// RELOG：服务端明确拒绝当前凭证（authInvalid）时统一清理 + 引导重登。
  /// 先校验代次并关闭内存认证，再清 secure 与普通账号资料；整个清理期间禁止新登录。
  /// 不主动导航；UI 靠既有 loginRequired 橙色 banner + 静态「重新登录」入口引导（用户已定）。
  Future<void> handleAuthInvalidation(AuthService service,
      {int? expectedEpoch, bool localLogout = false}) async {
    if (isDisposed) return;
    if (service == AuthService.ujing) {
      if (ujingAuthChanging ||
          (expectedEpoch != null && expectedEpoch != ujingAuthEpoch)) {
        return;
      }
      ujingAuthChanging = true;
      _invalidatedUjingEpoch = ujingAuthEpoch;
      _invalidatedUjingOwner = ujingAccountKey;
      ujingAuthEpoch++;
      invalidateDeviceStatus();
    } else {
      if (hotwaterAuthChanging ||
          (expectedEpoch != null && expectedEpoch != hotwaterAuthEpoch)) {
        return;
      }
      hotwaterAuthChanging = true;
    }
    if (service != AuthService.ujing) hotwaterAuthEpoch++;
    final message = localLogout ? '已退出本机登录' : '登录已失效，请重新登录';
    final kind = switch (service) {
      AuthService.zhuli => AccountKind.zhuli,
      AuthService.ujing => AccountKind.ujing,
      AuthService.shower798 => AccountKind.shower798,
    };
    emit(state.copyWith(
        account: state.account.copyWith(availability: {
      ...state.account.availability,
      kind: RuntimeActionStatus(
          state: RuntimeTaskState.loginRequired, message: message),
    })));
    try {
      switch (service) {
        case AuthService.ujing:
          stopWaterPolling();
          final adapter = ujing;
          if (adapter is UjingHttpAdapter) {
            adapter.invalidateAuth();
          }
          emit(state.copyWith(
            clearUjingAccount: true,
            devicesRefresh: RuntimeActionStatus(
                state: RuntimeTaskState.loginRequired, message: message),
            washerLogin: RuntimeActionStatus(
              state: RuntimeTaskState.loginRequired,
              message: message,
            ),
            waterScan: RuntimeActionStatus(
                state: RuntimeTaskState.loginRequired, message: message),
            waterOrder: RuntimeActionStatus(
                state: RuntimeTaskState.loginRequired, message: message),
            washer: state.washer.copyWith(
              clearProgram: true,
              washerScan: RuntimeActionStatus(
                  state: RuntimeTaskState.loginRequired, message: message),
              washerOrder: RuntimeActionStatus(
                  state: RuntimeTaskState.loginRequired, message: message),
              washerPayment: RuntimeActionStatus(
                  state: RuntimeTaskState.loginRequired, message: message),
            ),
          ));
          await Future.wait([secure.clearUjingToken(), sessions.clearUjing()]);
        case AuthService.zhuli:
          final adapter = hotwater;
          if (adapter is RealZhuliAdapter) {
            adapter.invalidateAuth();
          }
          emit(state.copyWith(
            zhuli: state.zhuli.copyWith(phone: ''),
            hotwaterLogin: RuntimeActionStatus(
              state: RuntimeTaskState.loginRequired,
              message: message,
            ),
          ));
          await Future.wait(
              [secure.clearZhuliSession(), sessions.clearZhuli()]);
        case AuthService.shower798:
          final adapter = shower798;
          if (adapter is RealShower798Adapter) {
            adapter.invalidateAuth();
          }
          emit(state.copyWith(
            clearShower798Account: true,
            shower798Login: RuntimeActionStatus(
              state: RuntimeTaskState.loginRequired,
              message: message,
            ),
          ));
          await Future.wait(
              [secure.clearShower798Token(), sessions.clearShower798()]);
      }
    } catch (error) {
      diagnosticLog.log('auth', '失效凭据清理失败 type=${error.runtimeType}');
      if (localLogout) rethrow;
    } finally {
      if (service == AuthService.ujing) {
        ujingAuthChanging = false;
      } else {
        hotwaterAuthChanging = false;
      }
    }
  }

  /// 把持久化快照应用到 seed state（main 预加载 + 异步恢复共用，避免双源）。
  static ShuiHomeState _applySnapshot(PersistedSnapshot snap) {
    final base = seedState();
    return base.copyWith(
      bathSystemPreference: snap.bathSystem,
      permissionIntroSeen: snap.permissionIntroSeen,
      zhuli: snap.zhuli,
      hotwaterLogin: snap.zhuli?.isLoggedIn ?? false
          ? RuntimeActionStatus(
              state: RuntimeTaskState.success,
              message: '住理生活已登录：${snap.zhuli!.phone}',
            )
          : base.hotwaterLogin,
      ujingAccount: snap.ujing,
      washerLogin: snap.ujing != null
          ? const RuntimeActionStatus(
              state: RuntimeTaskState.success,
              message: 'U净已登录',
            )
          : base.washerLogin,
      shower798Account: snap.shower798?.account.mobile.isNotEmpty == true
          ? snap.shower798?.account
          : null,
      shower798Devices: snap.shower798?.devices,
      currentShower798DeviceId: snap.shower798?.currentDeviceId,
      shower798Login: snap.shower798?.account.mobile.isNotEmpty == true
          ? RuntimeActionStatus(
              state: RuntimeTaskState.success,
              message: '慧生活798账号：${snap.shower798!.account.mobile}',
            )
          : base.shower798Login,
      // PDEV：持久化设备列表非 null 时整体替换 seed（含空列表 = 用户删空，绝不 re-seed）。
      localDevices: snap.localDevices
          ?.map((d) => d.copyWith(
              statusConfirmed: false,
              statusQueryFailed: false,
              statusCheckedAt: ''))
          .toList(),
      // P1-FIX：恢复时不再假冒「刚刚」（无真实刷新时刻可用）。留空 → UI 显「未刷新」，
      // 用户点刷新后才按真实时钟打戳（见 refreshLocalDevices）。
      localDevicesLastRefreshed: null,
      // PHIST：持久化热水历史非 null 时写入 hotwater.history（null → 保持空 → 首启走 adapter 拉取）。
      hotwater: snap.hotwaterSession == null
          ? base.hotwater.copyWith(history: snap.hotwaterHistory)
          : base.hotwater.copyWith(
              history: snap.hotwaterHistory,
              session: snap.hotwaterSession,
              running: snap.hotwaterSession!.mayHaveStarted,
              start: RuntimeActionStatus(
                state: snap.hotwaterSession!.mayHaveStarted
                    ? RuntimeTaskState.unavailable
                    : RuntimeTaskState.loading,
                message: snap.hotwaterSession!.mayHaveStarted
                    ? '热水使用中'
                    : '正在恢复上次启动状态',
              ),
            ),
      currentWaterOrder: snap.currentWaterOrder,
      waterHistory: snap.waterHistory ?? const <WaterOrderHistoryUi>[],
      washer: base.washer.copyWith(
          history: snap.washerHistory, currentOrder: snap.currentWasherOrder),
    );
  }

  /// 启动时回填已持久化状态（异步，完成后 emit 一次）。与预加载共用 AppBootstrap。
  Future<void> _restorePersisted() async {
    final snap = await AppBootstrap.load(
      settings,
      sessions,
      devices,
      history,
      water,
      washerHistoryRepository,
      migration: migration,
    );
    final restored = _applySnapshot(snap);
    applyRecoveryWarnings(snap);
    deviceSeq = _maxDeviceSeq(restored.localDevices);
    hotwaterOrderSeq = _maxOrderSeq(restored.hotwater.history);
    emit(restored);
  }

  /// 从热水历史派生 hotwaterOrderSeq 起点：取 orderId 尾号（如「热水-3」）的最大值，避免 append 撞号。
  static int _maxOrderSeq(List<HotwaterHistoryUi> history) {
    var max = 0;
    for (final h in history) {
      final match = RegExp(r'-(\d+)$').firstMatch(h.orderId);
      if (match != null) {
        final n = int.tryParse(match.group(1)!) ?? 0;
        if (n > max) {
          max = n;
        }
      }
    }
    return max;
  }

  /// 从设备列表派生 deviceSeq 起点：取 sortOrder 与 preset-/scanned- id 尾号的最大值。
  static int _maxDeviceSeq(List<LocalDeviceShortcut> list) {
    var max = 0;
    for (final d in list) {
      if (d.sortOrder > max) {
        max = d.sortOrder;
      }
      final match = RegExp(r'-(\d+)$').firstMatch(d.id);
      if (match != null) {
        final n = int.tryParse(match.group(1)!) ?? 0;
        if (n > max) {
          max = n;
        }
      }
    }
    return max;
  }

  /// 本地快捷入口 ID 分配序号，与服务端设备号无关。
  /// 初始 0；构造 + 恢复后由 [_maxDeviceSeq] 置为已存在设备的最大序号，避免撞号。
  int deviceSeq = 0;

  int deviceListRevision = 0;
  int _deviceStatusEpoch = 0;
  Future<void> _deviceCommitTail = Future<void>.value();

  bool deviceIdIsUnique(String id) =>
      id.trim().isNotEmpty &&
      state.localDevices.where((d) => d.id == id).length == 1;

  int nextDeviceSequence() {
    final max = _maxDeviceSeq(state.localDevices);
    if (max > deviceSeq) deviceSeq = max;
    do {
      deviceSeq++;
    } while (state.localDevices.any(
        (d) => d.id == 'preset-$deviceSeq' || d.id == 'scanned-$deviceSeq'));
    return deviceSeq;
  }

  void invalidateDeviceStatus({bool clearTimestamp = true}) {
    _deviceStatusEpoch++;
    emit(state.copyWith(
        localDevices: state.localDevices
            .map((d) => d.copyWith(statusConfirmed: false))
            .toList(),
        localDevicesLastRefreshed: clearTimestamp ? '' : null));
  }

  /// 所有本地列表写入共享此队列；调用方负责等待 ready。
  /// 网络等待不进入队列，变更函数只在轮到本次提交时读取最新列表。
  Future<DeviceChangeResult> commitDeviceList(
    List<LocalDeviceShortcut>? Function(List<LocalDeviceShortcut>) update, {
    bool replace = false,
  }) {
    final result = Completer<DeviceChangeResult>();
    _deviceCommitTail = _deviceCommitTail.then((_) async {
      if (isDisposed) {
        result.complete(const DeviceChangeResult(false, '页面已关闭'));
        return;
      }
      emit(state.copyWith(devicesSaving: true));
      try {
        final next = update(List.of(state.localDevices));
        if (next == null) {
          result.complete(const DeviceChangeResult(true, '无可提交的设备变化'));
          return;
        }
        final statusEpoch = _deviceStatusEpoch;
        await devices.saveDevices(next);
        if (isDisposed) {
          result.complete(const DeviceChangeResult(false, '页面已关闭'));
          return;
        }
        deviceListRevision++;
        emit(state.copyWith(
          localDevicesLastRefreshed: replace ? '' : null,
          devicesRefresh: replace ? const RuntimeActionStatus() : null,
          localDevices: List.unmodifiable(statusEpoch == _deviceStatusEpoch
              ? next
              : next.map((d) => d.copyWith(statusConfirmed: false))),
        ));
        result.complete(const DeviceChangeResult(true, '已保存'));
      } on FormatException catch (error) {
        result.complete(DeviceChangeResult(false, error.message));
      } catch (error) {
        diagnosticLog.log('storage', '设备保存失败 type=${error.runtimeType}');
        result.complete(const DeviceChangeResult(false, '设备保存失败，原列表已保留，请重试'));
      } finally {
        emit(state.copyWith(devicesSaving: false));
      }
    });
    return result.future;
  }

  /// 热水历史订单号自增计数器（PHIST）。初始 0；构造 + 恢复后由 [_maxOrderSeq]
  /// 置为已持久化历史 orderId 尾号的最大值，避免 append 撞号。HotwaterActions 读写它。
  int hotwaterOrderSeq = 0;

  /// Home banner 清理计时器（waterScan/washerScan）。
  Timer? _homeBannerTimer;

  /// Devices/Water 提示清理计时器。两个计时器独立，行为与拆分前一致。
  Timer? _deviceNoticeTimer;
  Timer? _hotwaterErrorTimer;
  Timer? _waterPollingTimer;
  bool _pollingPaused = false;
  bool get pollingPaused => _pollingPaused;

  Future<void> pollWaterOrderOnce();

  Future<void> pollHotwaterStatusOnce();

  Timer? _washerPollingTimer;
  bool _washerPollingReady = false;

  bool get _canPollWasher {
    final order = state.currentWasherOrder;
    return _washerPollingReady &&
        !isDisposed &&
        !pollingPaused &&
        !ujingOrderStorageBlocked &&
        legacyServiceReady('ujing') &&
        order != null &&
        !order.isTerminal &&
        !pendingLegacy('washer', order.orderId) &&
        canAccessUjingOrder(order.ownerAccountKey);
  }

  /// 页面无关的单一查询时钟，沿用既有 30 秒间隔；控制与手动查询共用运行时互斥。
  void syncWasherPolling() {
    if (!_canPollWasher) {
      _washerPollingTimer?.cancel();
      _washerPollingTimer = null;
      return;
    }
    _washerPollingTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (_canPollWasher) {
        unawaited(refreshCurrentWasherOrder());
      } else {
        syncWasherPolling();
      }
    });
  }

  Future<void> resumeWasherPolling() async {
    await ready;
    syncWasherPolling();
    if (_canPollWasher) await resumeWasherOrders();
  }

  void startWaterPolling() {
    if (isDisposed ||
        _pollingPaused ||
        state.currentWaterOrder == null ||
        pendingLegacy('water', state.currentWaterOrder!.orderId) ||
        !legacyServiceReady('ujing')) {
      return;
    }
    stopWaterPolling();
    _waterPollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pollingPaused) {
        unawaited(pollWaterOrderOnce());
      }
    });
  }

  /// 恢复有活动订单的饮水轮询：先立即补查，再保持 5 秒周期。
  void resumeWaterPolling() {
    final order = state.currentWaterOrder;
    if (isDisposed || _pollingPaused || order == null || order.isTerminal) {
      if (order == null || order.isTerminal) stopWaterPolling();
      return;
    }
    if (_waterPollingTimer == null) {
      startWaterPolling();
    }
    unawaited(pollWaterOrderOnce());
  }

  void stopWaterPolling() {
    _waterPollingTimer?.cancel();
    _waterPollingTimer = null;
  }

  void setPollingPaused(bool paused) {
    final wasPaused = _pollingPaused;
    _pollingPaused = paused;
    syncWasherPolling();
    if (wasPaused && !paused) {
      unawaited(resumeHotwaterSession());
      resumeWaterPolling();
      unawaited(resumeWasherPolling());
    }
  }

  /// 注册 Home banner 延后清理（4 秒）。重复调用取消上一个。
  void scheduleHomeBannerClear(VoidCallback onClear) {
    _homeBannerTimer?.cancel();
    _homeBannerTimer = Timer(const Duration(seconds: 4), onClear);
  }

  /// 注册 Devices/Water 提示延后清理（4 秒）。重复调用取消上一个。
  void scheduleDeviceNoticeClear(VoidCallback onClear) {
    _deviceNoticeTimer?.cancel();
    _deviceNoticeTimer = Timer(const Duration(seconds: 4), onClear);
  }

  void scheduleHotwaterErrorClear(VoidCallback onClear) {
    _hotwaterErrorTimer?.cancel();
    _hotwaterErrorTimer = Timer(const Duration(seconds: 3), onClear);
  }

  Future<void> persistWaterOrders() async {
    ujingMutationCount++;
    try {
      await water.save(WaterOrderSnapshot(
        currentOrder: state.currentWaterOrder,
        history: state.waterHistory,
      ));
    } finally {
      ujingMutationCount--;
    }
  }

  /// 记录首次权限引导已确认，避免下次启动重复弹出。
  void markPermissionIntroSeen() {
    if (state.permissionIntroSeen) {
      return;
    }
    emit(state.copyWith(permissionIntroSeen: true));
    unawaited(settings.savePermissionIntroSeen(true).catchError((Object error) {
      diagnosticLog.log('storage', '权限引导状态保存失败 type=${error.runtimeType}');
      emit(state.copyWith(permissionIntroSeen: false));
    }));
  }

  @override
  void dispose() {
    isDisposed = true;
    syncWasherPolling();
    _homeBannerTimer?.cancel();
    _deviceNoticeTimer?.cancel();
    _hotwaterErrorTimer?.cancel();
    stopWaterPolling();
    super.dispose();
  }

  /// 初始种子：空设备列表起步（PDEV）。设备由用户扫码/预设添加，添加后持久化，
  /// 重启从 [LocalDeviceRepository] 恢复用户的真实列表。首启无持久化记录 → 空列表。
  static ShuiHomeState seedState() {
    return const ShuiHomeState(
      localDevices: <LocalDeviceShortcut>[],
    );
  }
}
