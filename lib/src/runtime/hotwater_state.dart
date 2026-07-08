// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
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

  HotwaterState copyWith({
    bool? running,
    RuntimeActionStatus? start,
    RuntimeActionStatus? stop,
    List<HotwaterHistoryUi>? history,
    RuntimeActionStatus? historyStatus,
  }) {
    return HotwaterState(
      running: running ?? this.running,
      start: start ?? this.start,
      stop: stop ?? this.stop,
      history: history ?? this.history,
      historyStatus: historyStatus ?? this.historyStatus,
    );
  }
}
