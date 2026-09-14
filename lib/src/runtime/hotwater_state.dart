// Hotwater sub-state (no visual constants). Extracted from ShuiHomeState like AccountState/WasherState
// to keep the aggregate from bloating. Holds running flag + start/stop action status + history.

import 'package:flutter/foundation.dart';

import 'models/hotwater_history.dart';
import 'runtime_status.dart';

enum HotwaterSessionPhase { preparing, starting, uncertain, active }

/// 热水控制子状态（H1）。不可变 + copyWith。由 [ShuiHomeState.hotwater] 持有。
@immutable
class HotwaterState {
  const HotwaterState({
    this.running = false,
    this.start = const RuntimeActionStatus(),
    this.stop = const RuntimeActionStatus(),
    this.history = const <HotwaterHistoryUi>[],
    this.historyStatus = const RuntimeActionStatus(),
    this.session,
  });

  /// 热水/洗浴是否供应中。Home 进行中任务派生用它。
  final bool running;

  /// 开热水/开始洗浴动作状态。
  final RuntimeActionStatus start;

  /// 关热水/结束洗浴动作状态。
  final RuntimeActionStatus stop;

  /// 热水使用历史（fake 累积）。
  final List<HotwaterHistoryUi> history;

  /// 历史加载动作状态。
  final RuntimeActionStatus historyStatus;
  final HotwaterSession? session;

  HotwaterState copyWith({
    bool? running,
    RuntimeActionStatus? start,
    RuntimeActionStatus? stop,
    List<HotwaterHistoryUi>? history,
    RuntimeActionStatus? historyStatus,
    HotwaterSession? session,
    bool clearSession = false,
  }) {
    return HotwaterState(
      running: running ?? this.running,
      start: start ?? this.start,
      stop: stop ?? this.stop,
      history: history ?? this.history,
      historyStatus: historyStatus ?? this.historyStatus,
      session: clearSession ? null : session ?? this.session,
    );
  }
}

@immutable
class HotwaterSession {
  const HotwaterSession({
    required this.id,
    required this.account,
    required this.system,
    required this.simulated,
    required this.deviceId,
    required this.startedAtMillis,
    required this.baselineOrderIds,
    this.phase = HotwaterSessionPhase.preparing,
    this.orderId = '',
  });
  final String id;
  final String account;
  final BathSystemPreference system;
  final bool simulated;
  final String deviceId;
  final int startedAtMillis;
  final List<String> baselineOrderIds;
  final HotwaterSessionPhase phase;
  final String orderId;

  bool get canPoll =>
      phase == HotwaterSessionPhase.active ||
      phase == HotwaterSessionPhase.uncertain;

  HotwaterSession copyWith({
    HotwaterSessionPhase? phase,
    String? orderId,
  }) {
    return HotwaterSession(
      id: id,
      account: account,
      system: system,
      simulated: simulated,
      deviceId: deviceId,
      startedAtMillis: startedAtMillis,
      baselineOrderIds: baselineOrderIds,
      phase: phase ?? this.phase,
      orderId: orderId ?? this.orderId,
    );
  }

  // 比较已知订单集合而不是列表位置，避免排序变化被当成结束。
  bool hasNewConsumption(List<HotwaterHistoryUi> orders) => orders.any((order) {
        if (orderId.isNotEmpty) {
          return order.orderId == orderId;
        }
        final time = DateTime.tryParse(order.time);
        return order.deviceId == deviceId &&
            order.orderId.isNotEmpty &&
            !baselineOrderIds.contains(order.orderId) &&
            time != null &&
            time.millisecondsSinceEpoch ~/ 1000 >= startedAtMillis ~/ 1000;
      });

  Map<String, Object> toJson() => {
        'version': 2,
        'id': id,
        'account': account,
        'system': system.name,
        'simulated': simulated,
        'deviceId': deviceId,
        'startedAtMillis': startedAtMillis,
        'baselineOrderIds': baselineOrderIds,
        'phase': phase.name,
        'orderId': orderId,
      };

  static HotwaterSession fromJson(Map<String, dynamic> json) {
    try {
      final rawVersion = json['version'];
      final version = rawVersion == null
          ? 1
          : rawVersion is int
              ? rawVersion
              : throw const FormatException('Invalid hotwater session version');
      if (version != 1 && version != 2) {
        throw const FormatException('Unsupported hotwater session version');
      }

      final rawSystem = json['system'];
      final system = rawSystem is String
          ? BathSystemPreference.values.byName(rawSystem)
          : throw const FormatException('Invalid hotwater session system');
      final rawIds = json['baselineOrderIds'];
      if (rawIds is! List || rawIds.any((id) => id is! String)) {
        throw const FormatException('Invalid hotwater session baseline');
      }
      final rawOrderId = json['orderId'];
      if (version == 2 && rawOrderId != null && rawOrderId is! String) {
        throw const FormatException('Invalid hotwater session order');
      }

      final result = HotwaterSession(
        id: _requiredString(json['id'], 'id'),
        account: _requiredString(json['account'], 'account'),
        system: system,
        simulated: _requiredBool(json['simulated'], 'simulated'),
        deviceId: _requiredString(json['deviceId'], 'deviceId'),
        startedAtMillis: _requiredInt(
          json['startedAtMillis'],
          'startedAtMillis',
        ),
        baselineOrderIds: List<String>.unmodifiable(rawIds.cast<String>()),
        phase: version == 1
            ? HotwaterSessionPhase.uncertain
            : HotwaterSessionPhase.values.byName(json['phase'] as String),
        orderId: version == 2 ? (rawOrderId as String? ?? '') : '',
      );
      if (system == BathSystemPreference.none ||
          result.id.isEmpty ||
          result.account.isEmpty ||
          result.deviceId.isEmpty ||
          result.startedAtMillis <= 0) {
        throw const FormatException('Invalid hotwater session');
      }
      return result;
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid hotwater session: $error');
    }
  }

  static String _requiredString(Object? value, String field) {
    if (value is String) return value;
    throw FormatException('Invalid hotwater session $field');
  }

  static bool _requiredBool(Object? value, String field) {
    if (value is bool) return value;
    throw FormatException('Invalid hotwater session $field');
  }

  static int _requiredInt(Object? value, String field) {
    if (value is int) return value;
    throw FormatException('Invalid hotwater session $field');
  }
}
