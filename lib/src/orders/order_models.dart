// Orders view models (no visual constants). Normalizes hotwater/drinking/washer orders into a
// single OrderRowUi for the shared OrderListItem. Aligns with legacy OrderCategory + OrderUi.

import 'package:flutter/widgets.dart';

/// 订单分类（对齐 legacy OrderCategory）。
enum OrderCategory { hotwater, drinking, washer }

/// 归一化订单列表项视图模型。
///
/// 分类已经说明了订单类型，所以标题放最能区分订单的信息：洗衣、饮水是设备名，
/// 热水（同一个浴室）是时间。
@immutable
class OrderRowUi {
  const OrderRowUi({
    this.id = '',
    required this.title,
    this.subtitle = '',
    required this.amount,
    required this.status,
    required this.statusColor,
    required this.iconAsset,
    this.onTap,
  });

  final String id;
  final String title;

  /// 第二行说明（时间或剩余时间）；为空时不显示。
  final String subtitle;
  final String amount;
  final String status;
  final Color statusColor;
  final String iconAsset;

  /// 可选点击（当前订单跳详情/路由；历史项通常 null）。
  final VoidCallback? onTap;
}

/// 毫秒时间戳 → 「今天 HH:mm」/「M月d日 HH:mm」，不是今年的加上年份。
String formatOrderTime(int millis, int nowMillis) {
  final t = DateTime.fromMillisecondsSinceEpoch(millis);
  final now = DateTime.fromMillisecondsSinceEpoch(nowMillis);
  final hm =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (t.year == now.year && t.month == now.month && t.day == now.day) {
    return '今天 $hm';
  }
  if (t.year != now.year) return '${t.year}年${t.month}月${t.day}日 $hm';
  return '${t.month}月${t.day}日 $hm';
}
