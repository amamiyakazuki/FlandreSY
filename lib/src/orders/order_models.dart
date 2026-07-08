// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Orders view models (no visual constants). Normalizes hotwater/drinking/washer orders into a
// single OrderRowUi for the shared OrderListItem. Aligns with legacy OrderCategory + OrderUi.

import 'package:flutter/widgets.dart';

/// 订单分类（对齐 legacy OrderCategory）。
enum OrderCategory { hotwater, drinking, washer }

/// 归一化订单列表项视图模型（对齐 legacy OrderUi）。
@immutable
class OrderRowUi {
  const OrderRowUi({
    required this.type,
    required this.time,
    required this.device,
    required this.amount,
    required this.status,
    required this.statusColor,
    required this.iconAsset,
    this.onTap,
  });

  final String type;
  final String time;
  final String device;
  final String amount;
  final String status;
  final Color statusColor;
  final String iconAsset;

  /// 可选点击（当前订单跳详情/路由；历史项通常 null）。
  final VoidCallback? onTap;
}
