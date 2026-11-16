import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/shui_runtime.dart';
import '../runtime/models/hotwater_history.dart';
import '../orders/order_models.dart';
import '../theme/shui_assets.dart';
import '../widgets/order_list_item.dart';
import '../widgets/shui_components.dart';

/// 订单页「热水」分类的住理热水记录列表（只显示当前账号）。
class HotwaterHistoryPanel extends StatelessWidget {
  const HotwaterHistoryPanel({
    required this.state,
    this.onRefresh,
    this.nowMillis = _systemNow,
    super.key,
  });
  final ShuiHomeState state;
  final VoidCallback? onRefresh;

  /// 用于把记录时间显示成「今天 HH:mm」「M月d日 HH:mm」。
  final int Function() nowMillis;

  static int _systemNow() => DateTime.now().millisecondsSinceEpoch;

  @override
  Widget build(BuildContext context) {
    final status = state.hotwater.historyStatus;
    final rows = state.currentHotwaterHistory;
    final fallback = switch (status.state) {
      RuntimeTaskState.idle => rows.isEmpty ? '热水历史尚未加载' : '历史记录尚未刷新',
      RuntimeTaskState.loading => '正在加载热水历史',
      RuntimeTaskState.failure => '热水历史加载失败，请稍后重试',
      RuntimeTaskState.loginRequired => '请先登录住理账号后查询历史',
      RuntimeTaskState.permissionRequired => '查询热水历史所需权限尚未授予',
      RuntimeTaskState.paymentInProgress => '正在处理热水历史请求',
      RuntimeTaskState.unavailable => '热水历史暂不可用，请稍后重试',
      RuntimeTaskState.success => null,
    };
    final message = status.message?.trim().isNotEmpty == true
        ? status.message
        : !state.zhuli.isLoggedIn
            ? '请先登录住理账号后查询历史'
            : fallback;
    final now = nowMillis();
    // 和饮水、洗衣订单用同一种卡片；同一个浴室不需要设备名，标题直接用时间。
    Widget row(HotwaterHistoryUi h) {
      final at = h.timeMillis;
      return Padding(
        padding: const EdgeInsets.only(bottom: AppCustomTokens.spaceSm),
        child: OrderListItem(
          order: OrderRowUi(
            id: 'hotwater-${h.orderId}',
            title: at == null ? h.time : formatOrderTime(at, now),
            amount: h.amount,
            status: h.status,
            statusColor: AppColors.serviceGreen,
            iconAsset: ShuiAssets.shuiReshui,
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
            child: Text('热水记录', style: AppTypography.textTheme.titleMedium)),
        if (onRefresh != null)
          TextButton(
            onPressed:
                status.isBusy || !state.zhuli.isLoggedIn ? null : onRefresh,
            child: Text(status.isBusy ? '加载中' : '刷新'),
          ),
      ]),
      RuntimeStatusBanner(
          status: RuntimeActionStatus(state: status.state, message: message)),
      if (rows.isEmpty &&
          state.zhuli.isLoggedIn &&
          status.state == RuntimeTaskState.success)
        const Text('暂无热水历史'),
      const SizedBox(height: AppCustomTokens.spaceSm),
      ...rows.map(row),
    ]);
  }
}
