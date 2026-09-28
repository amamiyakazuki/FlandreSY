import 'dart:async';

import '../../data/adapters/hotwater_adapter.dart';
import '../../data/adapters/shower798_adapter.dart';
import '../../data/adapters/ujing_adapter.dart';
import '../models/account_session.dart';
import '../runtime_status.dart';
import '../shui_runtime_base.dart';

/// 只读登录检测和本机登出，不更改订单、设备配置或实体设备状态。
mixin AccountAvailabilityActions on ShuiRuntimeBase {
  final _checks = <AccountKind, (int, String, Future<void>)>{};
  final _revision = <AccountKind, int>{};

  int _epoch(AccountKind kind) =>
      kind == AccountKind.ujing ? ujingAuthEpoch : hotwaterAuthEpoch;
  String _owner(AccountKind kind) => switch (kind) {
        AccountKind.zhuli => state.zhuli.phone,
        AccountKind.ujing => state.ujingAccount?.mobile ?? '',
        AccountKind.shower798 => state.shower798Account?.mobile ?? '',
      };
  bool _changing(AccountKind kind) =>
      kind == AccountKind.ujing ? ujingAuthChanging : hotwaterAuthChanging;
  bool _writing(AccountKind kind) => kind == AccountKind.ujing
      ? ujingMutationCount > 0
      : hotwaterOperationInFlight || hotwaterAccountWriteCount > 0;
  AuthService _service(AccountKind kind) => switch (kind) {
        AccountKind.zhuli => AuthService.zhuli,
        AccountKind.ujing => AuthService.ujing,
        AccountKind.shower798 => AuthService.shower798,
      };

  void _status(AccountKind kind, RuntimeTaskState status, String? message) {
    emit(state.copyWith(
        account: state.account.copyWith(availability: {
      ...state.account.availability,
      kind: RuntimeActionStatus(state: status, message: message),
    })));
  }

  @override
  void resetAccountAvailability(AccountKind kind) {
    _revision[kind] = (_revision[kind] ?? 0) + 1;
    _checks.remove(kind);
    _status(kind, RuntimeTaskState.idle, null);
  }

  @override
  Future<void> checkAccountStatus(AccountKind kind) async {
    await ready;
    if (isDisposed) return;
    if (_changing(kind) || _writing(kind)) {
      _status(kind, RuntimeTaskState.unavailable, '账号或设备操作正在处理，请稍后检测');
      return;
    }
    final owner = _owner(kind);
    if (owner.isEmpty) {
      _status(kind, RuntimeTaskState.loginRequired, '尚未登录，请先登录');
      return;
    }
    final epoch = _epoch(kind);
    final pending = _checks[kind];
    if (pending != null && pending.$1 == epoch && pending.$2 == owner) {
      return pending.$3;
    }
    final revision = (_revision[kind] ?? 0) + 1;
    _revision[kind] = revision;
    _status(kind, RuntimeTaskState.loading, '正在检测登录是否有效…');
    late final Future<void> request;
    request = _probe(kind, epoch, owner, revision).whenComplete(() {
      if (identical(_checks[kind]?.$3, request)) _checks.remove(kind);
    });
    _checks[kind] = (epoch, owner, request);
    await request;
  }

  Future<void> _probe(
      AccountKind kind, int epoch, String owner, int revision) async {
    bool current() =>
        !isDisposed &&
        _revision[kind] == revision &&
        _epoch(kind) == epoch &&
        _owner(kind) == owner &&
        !_changing(kind);
    try {
      await switch (kind) {
        AccountKind.zhuli => hotwater.checkAccountValidity(),
        AccountKind.ujing => ujing.checkAccountValidity(),
        AccountKind.shower798 => shower798.checkAccountValidity(),
      }
          .timeout(const Duration(seconds: 15));
      if (!current()) return;
      _status(kind, RuntimeTaskState.success, '登录检测通过（仅代表本次验证有效）');
    } catch (error) {
      if (!current()) return;
      // 检测发出后也可能开始控制设备；只读探测不得截断在途控制的结果保全。
      if (_writing(kind)) {
        _status(kind, RuntimeTaskState.unavailable,
            '设备或订单操作正在处理，暂缓判定登录状态，请完成后重新检测');
        return;
      }
      final invalid = (error is HotwaterException && error.authInvalid) ||
          (error is UjingException && error.authInvalid) ||
          (error is Shower798Exception && error.authInvalid);
      if (invalid) {
        await handleAuthInvalidation(_service(kind), expectedEpoch: epoch);
        if (!isDisposed &&
            _revision[kind] == revision &&
            _owner(kind).isEmpty) {
          _status(kind, RuntimeTaskState.loginRequired, '登录已失效，请重新登录');
        }
      } else {
        // 不显示可能包含响应/凭据原文的异常，不因网络问题清账号。
        _status(kind, RuntimeTaskState.unavailable,
            '暂时无法验证登录状态，请检查网络后重试；当前登录信息已保留');
      }
    } finally {
      if (!isDisposed &&
          _revision[kind] == revision &&
          state.account.availability[kind]?.isBusy == true) {
        _status(kind, RuntimeTaskState.unavailable, '账号状态已变化，请重新检测');
      }
    }
  }

  @override
  Future<void> logoutAccount(AccountKind kind) async {
    await ready;
    if (isDisposed) return;
    if (_changing(kind) || _writing(kind)) {
      _status(
          kind, RuntimeTaskState.unavailable, '账号或设备操作正在处理，请完成后再退出；不会取消已发送的操作');
      return;
    }
    resetAccountAvailability(kind);
    final revision = _revision[kind];
    try {
      await handleAuthInvalidation(_service(kind), localLogout: true);
      if (!isDisposed && _revision[kind] == revision) {
        _status(kind, RuntimeTaskState.success, '已退出本机登录；订单和设备配置已保留，设备不会因此停止');
      }
    } catch (_) {
      if (!isDisposed && _revision[kind] == revision) {
        _status(
            kind, RuntimeTaskState.failure, '本机凭据清理未完成，已停止使用当前登录，请再次点击退出重试');
      }
    }
  }
}
