// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors, AppTypography.textTheme, AppCustomTokens space/radius/alpha.
// Reference: legacy ShuiScreens.kt CurrentWasherOrderPaymentCard (1299) + AutoStartNoticeCard + PriceBar.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/fake_shui_runtime.dart';
import '../runtime/models/washer_order.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_painters.dart';

/// 当前订单支付卡：订单信息 + 按状态条件 CTA（支付/启动/停止/取消）。
/// 对齐 legacy CurrentWasherOrderPaymentCard。
class CurrentWasherOrderPaymentCard extends StatelessWidget {
  const CurrentWasherOrderPaymentCard({
    required this.order,
    required this.paying,
    required this.orderBusy,
    required this.paymentMessage,
    required this.paymentState,
    required this.onPay,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
    super.key,
  });

  final WasherOrderUi order;
  final bool paying;
  final bool orderBusy;
  final String? paymentMessage;
  final RuntimeActionStatus paymentState;
  final VoidCallback onPay;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final canPay = order.status == '10';
    final canStart = order.status == '20';
    final canStop = order.status == '21' || order.status == '40';
    final busy = paying || orderBusy;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '当前订单',
                style: textTheme.titleMedium?.copyWith(color: AppColors.deepText),
              ),
              const Spacer(),
              StatusPill(
                text: order.statusText,
                color: AppColors.serviceOrange,
                filled: true,
              ),
            ],
          ),
          const SizedBox(height: AppCustomTokens.spaceSm),
          InfoLine(label: '订单号', value: order.orderId),
          InfoLine(label: '设备号', value: order.deviceNo),
          InfoLine(label: '金额', value: order.payPrice),
          if (order.remainTimeSeconds > 0)
            InfoLine(label: '剩余时间', value: _formatSeconds(order.remainTimeSeconds)),
          const SizedBox(height: AppCustomTokens.spaceXs),
          Text(
            '暂时只支持支付宝支付',
            style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
          ),
          if (paymentMessage != null) ...[
            const SizedBox(height: AppCustomTokens.spaceSm),
            RuntimeStatusBanner(status: paymentState),
          ],
          const SizedBox(height: AppCustomTokens.spaceSm),
          if (canPay) ...[
            PrimaryGradientButton(
              label: paying ? '支付中' : '支付宝支付',
              enabled: !busy,
              onTap: onPay,
            ),
            const SizedBox(height: AppCustomTokens.spaceSm),
            PrimaryGradientButton(
              label: orderBusy ? '处理中' : '取消订单',
              enabled: !busy,
              compact: true,
              onTap: onCancel,
            ),
          ] else if (canStart) ...[
            PrimaryGradientButton(
              label: orderBusy ? '启动中' : '启动洗衣机',
              enabled: !busy,
              onTap: onStart,
            ),
            const SizedBox(height: AppCustomTokens.spaceSm),
            PrimaryGradientButton(
              label: orderBusy ? '处理中' : '取消订单',
              enabled: !busy,
              compact: true,
              onTap: onCancel,
            ),
          ] else if (canStop)
            PrimaryGradientButton(
              label: orderBusy ? '处理中' : '提前停止',
              enabled: !busy,
              onTap: onStop,
            ),
        ],
      ),
    );
  }

  static String _formatSeconds(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final m = (safe ~/ 60).toString().padLeft(2, '0');
    final s = (safe % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// 自动启动开关卡（★ + 说明 + Switch）。对齐 legacy AutoStartNoticeCard。
class AutoStartNoticeCard extends StatelessWidget {
  const AutoStartNoticeCard({
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return SectionCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppCustomTokens.radiusMedium,
        vertical: AppCustomTokens.spaceSm,
      ),
      child: Row(
        children: [
          Text(
            '★',
            style: textTheme.titleMedium?.copyWith(color: AppColors.primary),
          ),
          const SizedBox(width: AppCustomTokens.radiusCompact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '支付成功后会自动启动洗衣机',
                  style:
                      textTheme.titleSmall?.copyWith(color: AppColors.deepText),
                ),
                Text(
                  enabled ? '支付宝返回成功后等待 3 秒发送启动指令' : '关闭后只保留预约，需要你手动启动',
                  // P2：说明句允许两行，避免被 Switch 挤裁。
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeThumbColor: AppColors.onPrimary,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: AppColors.onPrimary,
            inactiveTrackColor: AppColors.mutedText,
          ),
        ],
      ),
    );
  }
}

/// 底部价格栏（虚线框 + 大号预计价 + 创建按钮）。对齐 legacy PriceBar。
class PriceBar extends StatelessWidget {
  const PriceBar({
    required this.amount,
    required this.enabled,
    required this.buttonText,
    required this.onCreate,
    super.key,
  });

  final String amount;
  final bool enabled;
  final String buttonText;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return DashedBorderBox(
      color: AppColors.primaryLight,
      radius: AppCustomTokens.radiusLarge,
      padding: const EdgeInsets.symmetric(
        horizontal: AppCustomTokens.spaceMd,
        vertical: AppCustomTokens.radiusCompact,
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '预计价格',
                style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
              ),
              // P2 截断修复：预计价格大号数字用 FittedBox 缩放，避免与右侧按钮抢宽时溢出。
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  amount,
                  style:
                      textTheme.headlineSmall?.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppCustomTokens.spaceMd),
          Expanded(
            child: PrimaryGradientButton(
              label: buttonText,
              enabled: enabled,
              onTap: onCreate,
            ),
          ),
        ],
      ),
    );
  }
}
