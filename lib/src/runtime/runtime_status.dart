// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Pure runtime status/enums (no visual constants). Split out of fake_shui_runtime.dart
// for maintainability (Grok B1 Major 1 / B2 Major 1: avoid runtime aggregation).

import 'package:flutter/foundation.dart';

/// 通用动作状态机（对齐 legacy `RuntimeTaskState`）。
enum RuntimeTaskState {
  idle,
  loading,
  success,
  failure,
  loginRequired,
  permissionRequired,
  paymentInProgress,
  unavailable,
}

/// 洗浴系统偏好（住理 / 慧生活798）。
enum BathSystemPreference { zhuli, shower798 }

/// Home「进行中」任务的跳转目标。
enum HomeTaskTarget { hotwater, drinking, washer }

/// 单个动作的状态 + 文案，驱动 banner / 按钮 enabled / 文案。
@immutable
class RuntimeActionStatus {
  const RuntimeActionStatus({this.state = RuntimeTaskState.idle, this.message});

  final RuntimeTaskState state;
  final String? message;

  bool get isBusy =>
      state == RuntimeTaskState.loading ||
      state == RuntimeTaskState.paymentInProgress;
}

/// Home「进行中」卡片项。
@immutable
class HomeTaskUi {
  const HomeTaskUi({
    required this.target,
    required this.title,
    required this.extra,
    required this.asset,
  });

  final HomeTaskTarget target;
  final String title;
  final String extra;
  final String asset;
}
