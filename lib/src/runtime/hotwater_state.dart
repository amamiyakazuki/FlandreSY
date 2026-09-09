// Hotwater sub-state (no visual constants). Extracted from ShuiHomeState like AccountState/WasherState
// to keep the aggregate from bloating. Holds running flag + start/stop action status + history.

import 'package:flutter/foundation.dart';

import 'models/hotwater_history.dart';
import 'runtime_status.dart';

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
  });
  final String id;
  final String account;
  final BathSystemPreference system;
  final bool simulated;
  final String deviceId;
  final int startedAtMillis;
  final List<String> baselineOrderIds;

  // 比较已知订单集合而不是列表位置，避免排序变化被当成结束。
  bool hasNewConsumption(List<HotwaterHistoryUi> orders) => orders.any((order) {
        final time = DateTime.tryParse(order.time);
        return order.deviceId == deviceId &&
            order.orderId.isNotEmpty &&
            !baselineOrderIds.contains(order.orderId) &&
            time != null &&
            time.millisecondsSinceEpoch ~/ 1000 >= startedAtMillis ~/ 1000;
      });

  Map<String, Object> toJson() => {
        'version': 1,
        'id': id,
        'account': account,
        'system': system.name,
        'simulated': simulated,
        'deviceId': deviceId,
        'startedAtMillis': startedAtMillis,
        'baselineOrderIds': baselineOrderIds,
      };

  static HotwaterSession fromJson(Map<String, dynamic> json) {
    final system = BathSystemPreference.values.byName(json['system'] as String);
    final result = HotwaterSession(
      id: json['id'] as String,
      account: json['account'] as String,
      system: system,
      simulated: json['simulated'] as bool,
      deviceId: json['deviceId'] as String,
      startedAtMillis: json['startedAtMillis'] as int,
      baselineOrderIds:
          List<String>.unmodifiable(json['baselineOrderIds'] as List),
    );
    if (json['version'] != 1 ||
        system == BathSystemPreference.none ||
        result.id.isEmpty ||
        result.account.isEmpty ||
        result.deviceId.isEmpty ||
        result.startedAtMillis <= 0) {
      throw const FormatException('Invalid hotwater session');
    }
    return result;
  }
}
