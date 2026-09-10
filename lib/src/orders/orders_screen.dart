// Design tokens used: AppColors service palette, AppTypography.textTheme, AppCustomTokens space/shell.
// Reference: P_PLAN/...Reference.md §4.3 + legacy ShuiScreens.kt OrdersScreen (1927).

import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/fake_shui_runtime.dart';
import '../runtime/live_clock.dart';
import '../runtime/models/washer_order.dart';
import '../theme/shui_assets.dart';
import '../theme/shui_motion.dart';
import '../widgets/order_list_item.dart';
import '../widgets/shui_animated_list.dart';
import '../widgets/shui_header.dart';
import 'order_models.dart';

/// Orders 聚合页（W2）。3 分类切换 + 各类当前/历史 + 洗衣 live 倒计时（每秒）+ 30s 轮询。
/// 热水分类空态（真实热水控制未建）。
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    required this.state,
    required this.clock,
    required this.onBack,
    required this.onOpenWasherOrder,
    required this.onOpenDrinking,
    required this.onPollWasher,
    this.active = true,
    super.key,
  });

  final ShuiHomeState state;
  final LiveClock clock;
  final VoidCallback onBack;
  final VoidCallback onOpenWasherOrder;
  final VoidCallback onOpenDrinking;
  final VoidCallback onPollWasher;
  final bool active;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  OrderCategory _category = OrderCategory.hotwater;
  Timer? _tickTimer;
  Timer? _pollTimer;

  @override
  void dispose() {
    _tickTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  /// 仅在洗衣分类 + 有运行中当前订单时启动每秒 tick（live 倒计时）+ 30s 轮询。
  void _syncTimers() {
    final order = widget.state.washer.currentOrder;
    final needsLive = widget.active &&
        _category == OrderCategory.washer &&
        order != null &&
        !order.isTerminal;
    if (needsLive) {
      _tickTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      _pollTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) widget.onPollWasher();
      });
    } else {
      _tickTimer?.cancel();
      _tickTimer = null;
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncTimers();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = AppCustomTokens.bottomBarHeight +
        bottomInset +
        AppCustomTokens.bottomContentExtraPadding;
    return Scaffold(
      body: Column(
        children: [
          TopHeader(title: '历史订单', showBack: true, onBack: widget.onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppCustomTokens.spaceMd,
                AppCustomTokens.spaceSm,
                AppCustomTokens.spaceMd,
                bottomPadding,
              ),
              child: Column(
                children: [
                  _buildChipRow(),
                  const SizedBox(height: AppCustomTokens.spaceSm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      switch (_category) {
                        OrderCategory.hotwater => '住理账号近 30 天记录',
                        OrderCategory.drinking => '仅显示本机完成的接水订单',
                        OrderCategory.washer => '仅显示本机操作过的洗衣订单',
                      },
                      style: AppTypography.textTheme.bodySmall
                          ?.copyWith(color: AppColors.mutedText),
                    ),
                  ),
                  const SizedBox(height: AppCustomTokens.spaceSm),
                  AnimatedSwitcher(
                    duration: ShuiMotion.duration(context, ShuiMotion.local),
                    switchInCurve: ShuiMotion.easeOut,
                    switchOutCurve: ShuiMotion.easeIn,
                    child: Column(
                      key: ValueKey(_category),
                      children: _buildCategoryContent(),
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

  Widget _buildChipRow() {
    return Row(
      children: [
        Expanded(
          child: CategoryChip(
            text: '热水',
            iconAsset: ShuiAssets.shuiReshui,
            color: AppColors.primary,
            selected: _category == OrderCategory.hotwater,
            onTap: () => setState(() => _category = OrderCategory.hotwater),
          ),
        ),
        const SizedBox(width: AppCustomTokens.spaceSm),
        Expanded(
          child: CategoryChip(
            text: '饮水',
            iconAsset: ShuiAssets.shuiJieshui,
            color: AppColors.serviceBlue,
            selected: _category == OrderCategory.drinking,
            onTap: () => setState(() => _category = OrderCategory.drinking),
          ),
        ),
        const SizedBox(width: AppCustomTokens.spaceSm),
        Expanded(
          child: CategoryChip(
            text: '洗衣',
            iconAsset: ShuiAssets.shuiYifu,
            color: AppColors.serviceOrange,
            selected: _category == OrderCategory.washer,
            onTap: () => setState(() => _category = OrderCategory.washer),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCategoryContent() {
    final rows = switch (_category) {
      OrderCategory.hotwater => _hotwaterRows(),
      OrderCategory.drinking => _drinkingRows(),
      OrderCategory.washer => _washerRows(),
    };
    return [
      ShuiAnimatedList<OrderRowUi>(
        items: rows,
        identity: (row) => row.id,
        empty: _emptyForCategory(),
        itemBuilder: (row, _) => Padding(
            padding: const EdgeInsets.only(bottom: AppCustomTokens.spaceSm),
            child: OrderListItem(order: row)),
      ),
    ];
  }

  Widget _emptyForCategory() {
    return switch (_category) {
      OrderCategory.hotwater => const EmptyOrderState(
          title: '暂无热水订单',
          detail: '在热水控制页开启/关闭热水后，记录会显示在这里。',
        ),
      OrderCategory.drinking => const EmptyOrderState(
          title: '暂无饮水订单',
          detail: '本机完成的接水订单会显示在这里。',
        ),
      OrderCategory.washer => const EmptyOrderState(
          title: '暂无洗衣订单',
          detail: '本机操作过的洗衣订单会显示在这里。',
        ),
    };
  }

  List<OrderRowUi> _hotwaterRows() {
    return [
      for (final h in widget.state.hotwaterHistory)
        OrderRowUi(
          id: 'hotwater-${h.orderId}',
          type: '住理热水',
          time: h.time,
          device: '热水设备 ${h.deviceId}',
          amount: h.amount,
          status: h.status,
          statusColor: h.status.contains('使用')
              ? AppColors.serviceBlue
              : AppColors.serviceGreen,
          iconAsset: ShuiAssets.shuiReshui,
        ),
    ];
  }

  List<OrderRowUi> _drinkingRows() {
    final s = widget.state;
    final rows = <OrderRowUi>[];
    final current = s.currentWaterOrder;
    if (current != null) {
      rows.add(
        OrderRowUi(
          id: 'water-${current.orderId}',
          type: '饮水',
          time: '当前订单',
          device:
              '饮水机 ${current.deviceNo.isEmpty ? current.orderId : current.deviceNo}',
          amount: formatFenAmount((current.payment * 100).round()),
          status: current.statusRemark.isEmpty
              ? current.orderStatusName
              : current.statusRemark,
          statusColor: AppColors.serviceBlue,
          iconAsset: ShuiAssets.shuiJieshui,
          onTap: widget.onOpenDrinking,
        ),
      );
    }
    for (final h in s.waterHistory) {
      rows.add(
        OrderRowUi(
          id: 'water-${h.orderId}',
          type: '饮水',
          time: h.completedAt,
          device: '饮水机 ${h.deviceNo.isEmpty ? h.orderId : h.deviceNo}',
          amount: formatFenAmount((h.payment * 100).round()),
          status: h.status,
          statusColor: AppColors.serviceGreen,
          iconAsset: ShuiAssets.shuiJieshui,
        ),
      );
    }
    return rows;
  }

  List<OrderRowUi> _washerRows() {
    final s = widget.state;
    final rows = <OrderRowUi>[];
    final current = s.washer.currentOrder;
    if (current != null) {
      final now = widget.clock.nowMillis();
      final remain = liveRemainSeconds(
        current.remainTimeSeconds,
        current.refreshedAtMillis,
        now,
      );
      final timeText =
          remain > 0 ? '剩余 ${formatSeconds(remain)}' : current.statusText;
      rows.add(
        OrderRowUi(
          id: 'washer-${current.orderId}',
          type: '洗衣',
          time: timeText,
          device: '洗衣机 ${current.deviceNo}',
          amount: current.payPrice,
          status: current.statusText,
          statusColor: _washerStatusColor(current.status),
          iconAsset: ShuiAssets.shuiYifu,
          onTap: widget.onOpenWasherOrder,
        ),
      );
    }
    for (final h in s.washer.history) {
      if (current != null && h.orderId == current.orderId) {
        continue;
      }
      rows.add(
        OrderRowUi(
          id: 'washer-${h.orderId}',
          type: '洗衣',
          time: h.orderId,
          device: '洗衣机 ${h.deviceNo}',
          amount: h.payPrice,
          status: h.statusText,
          statusColor: _washerStatusColor(h.status),
          iconAsset: ShuiAssets.shuiYifu,
        ),
      );
    }
    return rows;
  }

  Color _washerStatusColor(String status) {
    return switch (status) {
      '40' || '21' => AppColors.serviceBlue,
      '50' => AppColors.serviceGreen,
      _ => AppColors.serviceOrange,
    };
  }
}
