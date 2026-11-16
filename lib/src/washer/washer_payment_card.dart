// Design tokens used: AppColors, AppTypography.textTheme, AppCustomTokens space/radius/alpha.
// Reference: legacy ShuiScreens.kt CurrentWasherOrderPaymentCard (1299) + AutoStartNoticeCard + PriceBar.

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/models/washer_order.dart';
import '../widgets/remove_local_record.dart';
import '../widgets/shui_components.dart';
import '../widgets/shui_painters.dart';

/// 当前洗衣订单卡：状态、实时剩余时间与按状态可用的操作。
/// 任何状态下都能刷新或移除本机记录，订单不会卡在无法操作的状态。
class CurrentWasherOrderPaymentCard extends StatelessWidget {
  const CurrentWasherOrderPaymentCard({
    required this.order,
    required this.nowMillis,
    required this.paying,
    required this.orderBusy,
    required this.autoStart,
    required this.onAutoStartChanged,
    required this.onPay,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
    required this.onRefresh,
    required this.onRemoveLocal,
    super.key,
  });

  final WasherOrderUi order;
  final int nowMillis;
  final bool paying;
  final bool orderBusy;
  final bool autoStart;
  final ValueChanged<bool> onAutoStartChanged;
  final VoidCallback onPay;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;
  final VoidCallback onRefresh;
  final VoidCallback onRemoveLocal;

  Color get _statusColor {
    if (order.isUnknown) return AppColors.mutedText;
    return switch (order.status) {
      WasherStatus.running || WasherStatus.starting => AppColors.serviceBlue,
      WasherStatus.reserved => AppColors.serviceGreen,
      _ => AppColors.serviceOrange,
    };
  }

  String? get _hint {
    if (order.isUnknown) {
      return '服务端返回了未识别的状态。可以刷新确认；如果订单已结束或已退款，可以移除本机记录。';
    }
    return switch (order.status) {
      WasherStatus.pending => '正在查询订单状态…',
      WasherStatus.unpaid => '暂时只支持支付宝支付',
      WasherStatus.reserved => '已支付，点击启动洗衣机',
      WasherStatus.starting => '正在启动，等待洗衣机确认',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final busy = paying || orderBusy;
    final remain = order.liveRemainSeconds(nowMillis);
    final hint = _hint;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('当前订单',
                  style: textTheme.titleMedium
                      ?.copyWith(color: AppColors.deepText)),
              const Spacer(),
              StatusPill(
                  text: order.statusLabel, color: _statusColor, filled: true),
            ],
          ),
          if (remain > 0) ...[
            const SizedBox(height: AppCustomTokens.spaceSm),
            Center(
              child: Text(formatSeconds(remain),
                  style: textTheme.headlineMedium
                      ?.copyWith(color: AppColors.serviceBlue)),
            ),
            Center(
              child: Text('预计剩余时间',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.mutedText)),
            ),
          ],
          const SizedBox(height: AppCustomTokens.spaceSm),
          if (order.deviceNo.isNotEmpty)
            InfoLine(label: '设备号', value: order.deviceNo),
          if (order.payPrice.isNotEmpty)
            InfoLine(label: '金额', value: order.payPrice),
          if (order.createdAtMillis > 0)
            InfoLine(
                label: '下单时间',
                value: formatOrderTime(order.createdAtMillis, nowMillis)),
          if (hint != null) ...[
            const SizedBox(height: AppCustomTokens.spaceXs),
            Text(hint,
                style:
                    textTheme.bodySmall?.copyWith(color: AppColors.mutedText)),
          ],
          const SizedBox(height: AppCustomTokens.spaceSm),
          if (order.canPay) ...[
            _AutoStartSwitch(value: autoStart, onChanged: onAutoStartChanged),
            const SizedBox(height: AppCustomTokens.spaceSm),
            PrimaryGradientButton(
                label: paying ? '等待支付结果' : '支付宝支付',
                enabled: !busy,
                onTap: onPay),
          ] else if (order.canStart)
            PrimaryGradientButton(
                label: orderBusy ? '处理中' : '启动洗衣机',
                enabled: !busy,
                onTap: onStart)
          else if (order.canStop)
            PrimaryGradientButton(
                label: orderBusy ? '处理中' : '提前停止',
                enabled: !busy,
                compact: true,
                onTap: onStop),
          if (order.canCancel) ...[
            const SizedBox(height: AppCustomTokens.spaceSm),
            PrimaryGradientButton(
                label: '取消订单', enabled: !busy, compact: true, onTap: onCancel),
          ],
          const SizedBox(height: AppCustomTokens.spaceXs),
          Row(
            children: [
              TextButton(
                onPressed: () => _confirmRemove(context),
                child: Text('移除本机记录',
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.mutedText)),
              ),
              const Spacer(),
              TextButton(
                onPressed: onRefresh,
                child: Text('刷新状态',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: AppColors.primary)),
              ),
            ],
          ),
          Text('订单号 ${order.orderId}',
              style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText)),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    if (await confirmRemoveLocalRecord(context,
        detail: '只会从本 App 中移除这笔订单，不会取消订单或退款，也不会控制洗衣机。'
            '适用于订单已结束、已退款或状态异常的情况。')) {
      onRemoveLocal();
    }
  }
}

class _AutoStartSwitch extends StatelessWidget {
  const _AutoStartSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('支付后自动启动',
                  style: textTheme.titleSmall
                      ?.copyWith(color: AppColors.deepText)),
              Text(
                value ? '确认付款后自动启动，回到 App 或稍后查询时也会补发' : '付款后需要手动启动',
                style:
                    textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.onPrimary,
          activeTrackColor: AppColors.primary,
        ),
      ],
    );
  }
}

/// 毫秒时间戳 → 当天显示「HH:mm」，其他日期显示「M月d日 HH:mm」。
String formatOrderTime(int millis, int nowMillis) {
  final t = DateTime.fromMillisecondsSinceEpoch(millis);
  final now = DateTime.fromMillisecondsSinceEpoch(nowMillis);
  final hm =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (t.year == now.year && t.month == now.month && t.day == now.day) {
    return '今天 $hm';
  }
  return '${t.month}月${t.day}日 $hm';
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
                style:
                    textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
              ),
              // P2 截断修复：预计价格大号数字用 FittedBox 缩放，避免与右侧按钮抢宽时溢出。
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  amount,
                  style: textTheme.headlineSmall
                      ?.copyWith(color: AppColors.primary),
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
