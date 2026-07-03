// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors palette, AppTypography.textTheme, AppCustomTokens spacing/radius/drinking sizing.
// Reference: P_PLAN/FlandreSY-Complete-Functions-and-UI-Design-Reference.md §4.11；legacy ShuiScreens.kt DrinkingWaterScreen.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/fake_shui_runtime.dart';
import '../runtime/models/water_order.dart';
import '../theme/shui_assets.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_header.dart';

/// 饮水接水页（B2）。对齐 legacy `DrinkingWaterScreen`：
/// 信息卡（饮水机/设备码/校区/余额 + 余额不足提示）+ 状态卡（订单详情 + 刷新）+ banner。
class DrinkingWaterScreen extends StatelessWidget {
  const DrinkingWaterScreen({
    required this.cd,
    required this.state,
    required this.onBack,
    required this.onRefresh,
    super.key,
  });

  final String cd;
  final ShuiHomeState state;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final ready = state.waterReady;
    final order = state.currentWaterOrder;
    final busy = state.waterOrder.isBusy;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = AppCustomTokens.bottomBarHeight +
        bottomInset +
        AppCustomTokens.bottomContentExtraPadding;

    return Scaffold(
      body: Column(
        children: [
          TopHeader(title: '饮水接单', showBack: true, onBack: onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppCustomTokens.spaceMd,
                AppCustomTokens.drinkingContentTopGap,
                AppCustomTokens.spaceMd,
                bottomPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.waterScan.message != null) ...[
                    RuntimeStatusBanner(status: state.waterScan),
                    const SizedBox(height: AppCustomTokens.drinkingCardGap),
                  ],
                  if (state.waterOrder.message != null) ...[
                    RuntimeStatusBanner(status: state.waterOrder),
                    const SizedBox(height: AppCustomTokens.drinkingCardGap),
                  ],
                  _InfoCard(cd: cd, ready: ready),
                  const SizedBox(height: AppCustomTokens.drinkingCardGap),
                  _StatusCard(order: order, busy: busy, onRefresh: onRefresh),
                  if (state.waterHistory.isNotEmpty) ...[
                    const SizedBox(height: AppCustomTokens.drinkingCardGap),
                    _HistoryCard(records: state.waterHistory),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.cd, required this.ready});

  final String cd;
  final WaterReadyUi? ready;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final balanceInsufficient = ready != null && ready!.balanceFen <= 0;
    return SectionCard(
      padding: const EdgeInsets.all(AppCustomTokens.spaceContent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DecorativeImage(
                ShuiAssets.shuiJieshui,
                size: AppCustomTokens.drinkingIconSize,
              ),
              const SizedBox(width: AppCustomTokens.drinkingCardGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '饮水机',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.deepText,
                      ),
                    ),
                    Text(
                      '设备码：${ready?.cd ?? (cd.isEmpty ? '未识别' : cd)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppCustomTokens.spaceSm),
          InfoLine(
            label: '校区',
            value: ready?.serviceSubjectName ?? '待确认',
          ),
          const SizedBox(height: AppCustomTokens.spaceXs),
          InfoLine(
            label: '余额',
            value: ready == null ? '待查询' : formatFenAmount(ready!.balanceFen),
          ),
          if (balanceInsufficient) ...[
            const SizedBox(height: AppCustomTokens.spaceSm),
            Text(
              '余额不足，请先在官方 App 充值',
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.serviceOrange,
              ),
            ),
          ],
          const SizedBox(height: AppCustomTokens.spaceSm),
          Text(
            '扫码后会自动创建接水订单；请在饮水机上按按钮开始或停止接水。',
            style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.order,
    required this.busy,
    required this.onRefresh,
  });

  final WaterOrderUi? order;
  final bool busy;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return SectionCard(
      padding: const EdgeInsets.all(AppCustomTokens.spaceContent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '接水状态',
            style: textTheme.titleMedium?.copyWith(color: AppColors.deepText),
          ),
          const SizedBox(height: AppCustomTokens.spaceSm),
          if (order == null)
            Text(
              '创建订单后，请在饮水机上按按钮开始接水；再次按机器按钮停止后，回到这里刷新状态。',
              style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
            )
          else ...[
            InfoLine(label: '订单号', value: order!.orderId),
            const SizedBox(height: AppCustomTokens.spaceXs),
            InfoLine(
              label: '状态',
              value: order!.statusRemark.isEmpty
                  ? order!.orderStatusName
                  : order!.statusRemark,
            ),
            const SizedBox(height: AppCustomTokens.spaceXs),
            InfoLine(
              label: '设备',
              value: order!.deviceNo.isEmpty ? '未知' : order!.deviceNo,
            ),
            const SizedBox(height: AppCustomTokens.spaceXs),
            InfoLine(
              label: '用水量',
              value: order!.warmWaterMl > 0
                  ? '${order!.warmWaterMl} ml'
                  : '等待机器上报',
            ),
            const SizedBox(height: AppCustomTokens.spaceXs),
            InfoLine(
              label: '用时',
              value: order!.waterSeconds > 0
                  ? '${order!.waterSeconds} 秒'
                  : '等待机器上报',
            ),
            const SizedBox(height: AppCustomTokens.spaceXs),
            InfoLine(label: '扣费', value: formatYuanAmount(order!.payment)),
          ],
          const SizedBox(height: AppCustomTokens.spaceMd),
          PrimaryGradientButton(
            label: busy ? '刷新中…' : '刷新状态',
            enabled: !busy && order != null,
            onTap: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.records});

  final List<WaterOrderHistoryUi> records;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return SectionCard(
      padding: const EdgeInsets.all(AppCustomTokens.spaceContent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '接水记录',
            style: textTheme.titleMedium?.copyWith(color: AppColors.deepText),
          ),
          const SizedBox(height: AppCustomTokens.spaceSm),
          ...records.reversed.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: AppCustomTokens.spaceXs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${record.completedAt} · ${record.warmWaterMl}ml / ${record.waterSeconds}秒',
                      // P2：用水记录（时间·用量/秒）允许两行，避免与右侧金额抢宽被裁。
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.deepText,
                      ),
                    ),
                  ),
                  Text(
                    formatYuanAmount(record.payment),
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.serviceGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
