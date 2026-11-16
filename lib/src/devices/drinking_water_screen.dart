// Design tokens used: AppColors palette, AppTypography.textTheme, AppCustomTokens spacing/radius/drinking sizing.
// Reference: P_PLAN/FlandreSY-Complete-Functions-and-UI-Design-Reference.md §4.11；legacy ShuiScreens.kt DrinkingWaterScreen.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/shui_runtime.dart';
import '../runtime/models/water_order.dart';
import '../theme/shui_motion.dart';
import '../theme/shui_assets.dart';
import '../widgets/remove_local_record.dart';
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
    required this.onRemoveLocal,
    this.onReturnHome,
    super.key,
  });

  final String cd;
  final ShuiHomeState state;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onRemoveLocal;
  final VoidCallback? onReturnHome;

  /// 识别结果只在没有订单提示时才单独显示：订单提示里已经包含下一步怎么做，
  /// 校区在下面的饮水机卡片里也有。识别失败总是显示；空闲时的默认提示不显示。
  bool get _showScanBanner {
    final scan = state.waterScan;
    if (scan.message == null || scan.state == RuntimeTaskState.idle) {
      return false;
    }
    if (scan.state == RuntimeTaskState.failure) return true;
    return state.waterOrder.message == null;
  }

  @override
  Widget build(BuildContext context) {
    final ready = state.waterReady;
    final order = state.currentWaterOrder;
    final result = state.waterResult;
    final busy = state.waterOrder.isBusy;
    final account = state.ujingAccountKey;
    final recent = state.waterHistory
        .where((h) =>
            account.isEmpty ||
            h.ownerAccountKey.isEmpty ||
            h.ownerAccountKey == account)
        .take(5)
        .toList();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = bottomInset + AppCustomTokens.spaceLg;

    return Scaffold(
      body: Column(
        children: [
          TopHeader(title: '饮水', showBack: true, onBack: onBack),
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
                  if (_showScanBanner) ...[
                    RuntimeStatusBanner(status: state.waterScan),
                    const SizedBox(height: AppCustomTokens.drinkingCardGap),
                  ],
                  if (state.waterOrder.message != null) ...[
                    RuntimeStatusBanner(status: state.waterOrder),
                    const SizedBox(height: AppCustomTokens.drinkingCardGap),
                  ],
                  _InfoCard(cd: cd, ready: ready),
                  const SizedBox(height: AppCustomTokens.drinkingCardGap),
                  AnimatedSwitcher(
                    duration: ShuiMotion.duration(context, ShuiMotion.local),
                    switchInCurve: ShuiMotion.easeOut,
                    switchOutCurve: ShuiMotion.easeIn,
                    child: result != null && order == null
                        ? _CompletedCard(
                            key: ValueKey(result.orderId),
                            order: result,
                            onBack: onReturnHome ?? onBack,
                          )
                        : _StatusCard(
                            key: ValueKey(order?.orderId ?? 'empty'),
                            order: order,
                            busy: busy,
                            onRefresh: onRefresh,
                            onRemoveLocal: onRemoveLocal,
                          ),
                  ),
                  if (recent.isNotEmpty) ...[
                    const SizedBox(height: AppCustomTokens.drinkingCardGap),
                    _HistoryCard(records: recent),
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

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({required this.order, required this.onBack, super.key});

  final WaterOrderUi order;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            order.statusRemark.isNotEmpty
                ? order.statusRemark
                : order.orderStatusName,
            style: AppTypography.textTheme.titleLarge?.copyWith(
              color: AppColors.serviceGreen,
            ),
          ),
          const SizedBox(height: AppCustomTokens.spaceSm),
          if (order.deviceNo.isNotEmpty)
            InfoLine(label: '设备', value: order.deviceNo),
          InfoLine(label: '用水量', value: '${order.warmWaterMl} ml'),
          InfoLine(label: '扣费', value: formatYuanAmount(order.payment)),
          const SizedBox(height: AppCustomTokens.spaceMd),
          PrimaryGradientButton(label: '返回首页', onTap: onBack),
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
    required this.onRemoveLocal,
    super.key,
  });

  final WaterOrderUi? order;
  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback onRemoveLocal;

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
            InfoLine(label: '状态', value: order!.statusLabel),
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
            InfoLine(
              label: '扣费',
              // 没结束时服务端还没结算，¥0.00 看起来像免费。
              value: !order!.isTerminal && order!.payment == 0
                  ? '结束后结算'
                  : formatYuanAmount(order!.payment),
            ),
            const SizedBox(height: AppCustomTokens.spaceMd),
            PrimaryGradientButton(
              label: busy ? '刷新中…' : '刷新状态',
              enabled: !busy,
              onTap: onRefresh,
            ),
            const SizedBox(height: AppCustomTokens.spaceXs),
            // 与上面各行左对齐，不留按钮默认的内边距。
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, AppCustomTokens.spaceXl),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerLeft,
              ),
              onPressed: () async {
                if (await confirmRemoveLocalRecord(context,
                    detail: '只会从本 App 中移除这笔接水订单，不会影响饮水机或扣费。'
                        '适用于已在机器上结束、但这里一直没有更新的情况。')) {
                  onRemoveLocal();
                }
              },
              child: Text('移除本机记录',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.mutedText)),
            ),
          ],
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
            '最近接水',
            style: textTheme.titleMedium?.copyWith(color: AppColors.deepText),
          ),
          const SizedBox(height: AppCustomTokens.spaceSm),
          ...records.map(
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
