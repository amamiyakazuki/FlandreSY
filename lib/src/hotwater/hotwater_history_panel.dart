import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/shui_runtime.dart';
import '../runtime/models/hotwater_history.dart';
import '../widgets/shui_components.dart';

/// 订单与控制详情共用历史视图；旧档案独立展示，绝不作为当前账号结果。
class HotwaterHistoryPanel extends StatelessWidget {
  const HotwaterHistoryPanel({required this.state, this.onRefresh, super.key});
  final ShuiHomeState state;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final status = state.hotwater.historyStatus;
    final rows = state.currentHotwaterHistory;
    final legacy = state.unassignedHotwaterHistory;
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
          child: _HistoryRow(
              time: h.time,
              device: '设备 ${h.deviceId}',
              amount: h.amount,
              status: h.status),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('住理热水历史', style: AppTypography.textTheme.titleMedium),
      const SizedBox(height: AppCustomTokens.spaceSm),
      Text(state.zhuli.isLoggedIn ? '当前住理账号近 30 天记录' : '登录后查看账号历史',
          style: AppTypography.textTheme.bodySmall),
      RuntimeStatusBanner(
          status: RuntimeActionStatus(state: status.state, message: message)),
      if (onRefresh != null)
        Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed:
                  status.isBusy || !state.zhuli.isLoggedIn ? null : onRefresh,
              child: Text(status.isBusy ? '正在加载历史' : '刷新热水历史'),
            )),
      if (rows.isNotEmpty && status.state != RuntimeTaskState.success)
        const Text('以下为本地缓存，尚未确认最新记录'),
      if (rows.isEmpty &&
          state.zhuli.isLoggedIn &&
          status.state == RuntimeTaskState.success)
        const Text('暂无热水历史'),
      ...rows.map(row),
      if (legacy.isNotEmpty)
        ExpansionTile(
          title: Text('旧记录（归属待核对）· ${legacy.length}'),
          children: [
            const Text('这些旧记录已保留，无法确认所属账号，不计入当前账号历史。'),
            ...legacy.map(row),
          ],
        ),
    ]);
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.time,
    required this.device,
    required this.amount,
    required this.status,
  });

  final String time;
  final String device;
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
          Text(
            time,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.deepText),
          ),
          const SizedBox(height: AppCustomTokens.spaceXs),
          Text(
            device,
            softWrap: true,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.deepText),
          ),
          const SizedBox(height: AppCustomTokens.spaceSm),
          Wrap(
            spacing: AppCustomTokens.spaceSm,
            runSpacing: AppCustomTokens.spaceXs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                amount,
                style:
                    textTheme.titleSmall?.copyWith(color: AppColors.deepText),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppCustomTokens.spaceSm,
                    vertical: AppCustomTokens.spaceXs),
                decoration: BoxDecoration(
                  color: AppColors.serviceGreen
                      .withValues(alpha: AppCustomTokens.alphaChip),
                  borderRadius:
                      BorderRadius.circular(AppCustomTokens.radiusSmall),
                  border: Border.all(
                      color: AppColors.serviceGreen
                          .withValues(alpha: AppCustomTokens.alphaSoftBorder)),
                ),
                child: Text(status,
                    style: textTheme.labelMedium
                        ?.copyWith(color: AppColors.serviceGreen)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
