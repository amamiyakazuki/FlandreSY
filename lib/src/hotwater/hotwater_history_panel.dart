import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/shui_runtime.dart';
import '../runtime/models/hotwater_history.dart';
import '../widgets/shui_components.dart';

/// 订单页与热水详情共用的住理热水记录列表（只显示当前账号）。
class HotwaterHistoryPanel extends StatelessWidget {
  const HotwaterHistoryPanel({required this.state, this.onRefresh, super.key});
  final ShuiHomeState state;
  final VoidCallback? onRefresh;

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
    Widget row(HotwaterHistoryUi h) => Padding(
          padding: const EdgeInsets.only(bottom: AppCustomTokens.spaceSm),
          child: _HistoryRow(time: h.time, amount: h.amount, status: h.status),
        );
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.time,
    required this.amount,
    required this.status,
  });

  final String time;
  final String amount;
  final String status;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppCustomTokens.radiusMedium,
        vertical: AppCustomTokens.spaceSm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppCustomTokens.radiusMedium),
        border: Border.all(
          color: AppColors.cardBorder
              .withValues(alpha: AppCustomTokens.alphaOverlay),
          width: AppCustomTokens.strokeThin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(time,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.deepText)),
          const SizedBox(height: AppCustomTokens.spaceXs),
          Wrap(
            spacing: AppCustomTokens.spaceSm,
            runSpacing: AppCustomTokens.spaceXs,
            children: [
              Text(amount,
                  style: textTheme.titleSmall
                      ?.copyWith(color: AppColors.deepText)),
              Text(status,
                  style: textTheme.labelMedium
                      ?.copyWith(color: AppColors.serviceGreen)),
            ],
          ),
        ],
      ),
    );
  }
}
