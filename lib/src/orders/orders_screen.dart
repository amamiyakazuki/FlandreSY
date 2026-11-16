// Design tokens used: AppColors service palette, AppTypography.textTheme, AppCustomTokens space/shell.
// Reference: P_PLAN/...Reference.md §4.3 + legacy ShuiScreens.kt OrdersScreen (1927).

import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_tokens.dart';
import '../runtime/shui_runtime.dart';
import '../hotwater/hotwater_history_panel.dart';
import '../runtime/live_clock.dart';
import '../runtime/models/washer_order.dart';
import '../theme/shui_assets.dart';
import '../theme/shui_motion.dart';
import '../widgets/order_list_item.dart';
import '../widgets/shui_animated_list.dart';
import '../stats/spending_stats.dart';
import '../washer/washer_payment_card.dart' show formatOrderTime;
import '../widgets/shui_components.dart';
import '../widgets/shui_header.dart';
import 'order_models.dart';

/// Orders 聚合页：分类和历史展示，洗衣倒计时每秒更新；网络查询由运行时统一管理。
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    required this.state,
    required this.clock,
    required this.onBack,
    required this.onOpenWasherOrder,
    required this.onOpenDrinking,
    this.active = true,
    this.onRefreshHotwater,
    this.onOpenStats,
    super.key,
  });

  final ShuiHomeState state;
  final LiveClock clock;
  final VoidCallback onBack;
  final VoidCallback onOpenWasherOrder;
  final VoidCallback onOpenDrinking;
  final bool active;
  final VoidCallback? onRefreshHotwater;
  final VoidCallback? onOpenStats;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  OrderCategory _category = OrderCategory.hotwater;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _scheduleHistoryLoad();
  }

  @override
  void didUpdateWidget(covariant OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!oldWidget.active && widget.active) ||
        oldWidget.state.zhuli.phone != widget.state.zhuli.phone ||
        oldWidget.state.hotwaterLogin.state !=
            widget.state.hotwaterLogin.state) {
      _scheduleHistoryLoad();
    }
  }

  bool _historyLoadScheduled = false;
  void _scheduleHistoryLoad() {
    if (_historyLoadScheduled ||
        !widget.active ||
        _category != OrderCategory.hotwater) {
      return;
    }
    _historyLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _historyLoadScheduled = false;
      if (mounted && widget.active && _category == OrderCategory.hotwater) {
        widget.onRefreshHotwater?.call();
      }
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  /// 仅在可见洗衣分类且有活动订单时更新倒计时，不承担网络查询。
  void _syncTimers() {
    final order = widget.state.currentWasherOrder;
    final needsLive = widget.active &&
        _category == OrderCategory.washer &&
        order != null &&
        !order.isTerminal;
    if (needsLive) {
      _tickTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _tickTimer?.cancel();
      _tickTimer = null;
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
                  if (widget.onOpenStats != null) ...[
                    _MonthSpendingEntry(
                      state: widget.state,
                      nowMillis: widget.clock.nowMillis(),
                      onTap: widget.onOpenStats!,
                    ),
                    const SizedBox(height: AppCustomTokens.spaceSm),
                  ],
                  _buildChipRow(),
                  const SizedBox(height: AppCustomTokens.spaceSm),
                  if (_category != OrderCategory.hotwater &&
                      widget.state.otherAccountActiveOrders > 0) ...[
                    _OtherAccountHint(
                        count: widget.state.otherAccountActiveOrders),
                    const SizedBox(height: AppCustomTokens.spaceSm),
                  ],
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
            onTap: () {
              final changed = _category != OrderCategory.hotwater;
              setState(() => _category = OrderCategory.hotwater);
              if (changed) _scheduleHistoryLoad();
            },
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
    if (_category == OrderCategory.hotwater) {
      return [
        HotwaterHistoryPanel(
            state: widget.state, onRefresh: widget.onRefreshHotwater)
      ];
    }
    final rows = switch (_category) {
      OrderCategory.hotwater => <OrderRowUi>[],
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
          detail: '登录住理账号并刷新后可查看热水历史。',
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

  /// 已登录时只显示当前账号的记录；未登录时显示全部。
  bool _visible(String owner) {
    final key = widget.state.ujingAccountKey;
    return key.isEmpty || owner.isEmpty || owner == key;
  }

  List<OrderRowUi> _drinkingRows() {
    final s = widget.state;
    final now = widget.clock.nowMillis();
    final rows = <OrderRowUi>[];
    final current = s.currentWaterOrder;
    if (current != null) {
      rows.add(
        OrderRowUi(
          id: 'water-${current.orderId}',
          type: '饮水',
          time: current.createdAtMillis > 0
              ? formatOrderTime(current.createdAtMillis, now)
              : '进行中',
          device: current.deviceNo.isEmpty ? '饮水机' : '饮水机 ${current.deviceNo}',
          amount: current.payment > 0
              ? formatFenAmount((current.payment * 100).round())
              : '',
          status: current.statusLabel,
          statusColor: AppColors.serviceBlue,
          iconAsset: ShuiAssets.shuiJieshui,
          onTap: widget.onOpenDrinking,
        ),
      );
    }
    for (final h in s.waterHistory) {
      if (!_visible(h.ownerAccountKey)) continue;
      rows.add(
        OrderRowUi(
          id: 'water-${h.orderId}',
          type: '饮水',
          time: h.completedAtMillis > 0
              ? formatOrderTime(h.completedAtMillis, now)
              : h.completedAt,
          device: h.deviceNo.isEmpty ? '饮水机' : '饮水机 ${h.deviceNo}',
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
    final now = widget.clock.nowMillis();
    final rows = <OrderRowUi>[];
    final current = s.currentWasherOrder;
    if (current != null) {
      final remain = current.liveRemainSeconds(now);
      rows.add(
        OrderRowUi(
          id: 'washer-${current.orderId}',
          type: '洗衣',
          time: remain > 0
              ? '剩余 ${formatSeconds(remain)}'
              : current.createdAtMillis > 0
                  ? formatOrderTime(current.createdAtMillis, now)
                  : '进行中',
          device: current.deviceNo.isEmpty ? '洗衣机' : '洗衣机 ${current.deviceNo}',
          amount: current.payPrice,
          status: current.statusLabel,
          statusColor: _washerStatusColor(current.status),
          iconAsset: ShuiAssets.shuiYifu,
          onTap: widget.onOpenWasherOrder,
        ),
      );
    }
    for (final h in s.washer.history) {
      if (!_visible(h.ownerAccountKey)) continue;
      rows.add(
        OrderRowUi(
          id: 'washer-${h.orderId}',
          type: '洗衣',
          time: h.createdAtMillis > 0
              ? formatOrderTime(h.createdAtMillis, now)
              : '',
          device: h.deviceNo.isEmpty ? '洗衣机' : '洗衣机 ${h.deviceNo}',
          amount: h.payPrice,
          status: h.statusText.isEmpty
              ? WasherStatus.label(h.status)
              : h.statusText,
          statusColor: _washerStatusColor(h.status),
          iconAsset: ShuiAssets.shuiYifu,
        ),
      );
    }
    return rows;
  }

  Color _washerStatusColor(String status) {
    return switch (status) {
      WasherStatus.running || WasherStatus.starting => AppColors.serviceBlue,
      WasherStatus.finished => AppColors.serviceGreen,
      WasherStatus.cancelled || WasherStatus.removed => AppColors.mutedText,
      _ => AppColors.serviceOrange,
    };
  }
}

/// 其他账号仍有进行中的订单时提示（订单按账号保存，切回原账号即可操作）。
class _OtherAccountHint extends StatelessWidget {
  const _OtherAccountHint({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return RuntimeStatusBanner(
      status: RuntimeActionStatus(
        state: RuntimeTaskState.idle,
        message: '其他 U净 账号还有 $count 笔进行中的订单，切换回对应账号后可查看和操作',
      ),
    );
  }
}

/// 订单页顶部的本月消费入口（一行）。
class _MonthSpendingEntry extends StatelessWidget {
  const _MonthSpendingEntry({
    required this.state,
    required this.nowMillis,
    required this.onTap,
  });

  final ShuiHomeState state;
  final int nowMillis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final month =
        SpendingStats.compute(state).month(MonthKey.fromMillis(nowMillis));
    return ShuiPressable(
      soft: true,
      onTap: onTap,
      child: SectionCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppCustomTokens.spaceMd,
          vertical: AppCustomTokens.spaceSm,
        ),
        child: Row(
          children: [
            Text('本月消费',
                style:
                    textTheme.bodyMedium?.copyWith(color: AppColors.mutedText)),
            const SizedBox(width: AppCustomTokens.spaceSm),
            Expanded(
              child: Text(formatFen(month.totalFen),
                  style: textTheme.titleMedium
                      ?.copyWith(color: AppColors.deepText)),
            ),
            Text('统计 ›',
                style:
                    textTheme.bodyMedium?.copyWith(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}
