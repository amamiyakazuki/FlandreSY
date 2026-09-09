// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Drinking-water order persistence abstraction (no visual constants). Same decoupling pattern as
// HistoryRepository (PHIST) / LocalDeviceRepository (PDEV). PWATER (Phase 3 问题7): the current
// water order (state.currentWaterOrder) + completed history (state.waterHistory) previously lived
// only in memory → an app restart dropped them, so 订单页饮水分类 went empty even after 接水.
// Now both round-trip through this repository: 创建即记录当前订单，完成转历史，重启恢复。

import 'dart:convert';

import '../runtime/models/water_order.dart';

/// 饮水订单持久化的聚合快照：当前进行中订单（可空）+ 已完成历史列表。
class WaterOrderSnapshot {
  const WaterOrderSnapshot({
    this.currentOrder,
    this.history = const <WaterOrderHistoryUi>[],
  });

  /// 进行中的当前接水订单（创建后、完成前）。null = 无当前订单。
  final WaterOrderUi? currentOrder;

  /// 已完成的接水历史。
  final List<WaterOrderHistoryUi> history;
}

/// 饮水订单持久化接口（PWATER）。与 [HistoryRepository] 同构。
///
/// [load] 返回 null 表示「从未持久化过」（首启，无饮水数据）；返回非 null 快照表示
/// 恢复用户上次的当前订单 + 历史。
abstract class WaterOrderRepository {
  Future<WaterOrderSnapshot?> load();
  Future<void> save(WaterOrderSnapshot snapshot);
}

/// 饮水订单 JSON 编解码（对齐 [WaterOrderUi] / [WaterOrderHistoryUi] 全字段）。
/// 抽成静态供 SharedPrefs 实现 + fixture 直用。
class WaterOrderCodec {
  const WaterOrderCodec._();

  static String encode(WaterOrderSnapshot snapshot) {
    return jsonEncode(<String, dynamic>{
      'currentOrder': snapshot.currentOrder == null
          ? null
          : orderToMap(snapshot.currentOrder!),
      'history': snapshot.history.map(historyToMap).toList(),
    });
  }

  static WaterOrderSnapshot decode(String json) {
    if (json.isEmpty) {
      return const WaterOrderSnapshot();
    }
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      return const WaterOrderSnapshot();
    }
    final map = decoded.cast<String, dynamic>();
    final currentRaw = map['currentOrder'];
    final historyRaw = map['history'];
    final history = <WaterOrderHistoryUi>[];
    if (historyRaw is List) {
      for (final item in historyRaw) {
        if (item is Map) {
          history.add(historyFromMap(item.cast<String, dynamic>()));
        }
      }
    }
    return WaterOrderSnapshot(
      currentOrder: currentRaw is Map
          ? orderFromMap(currentRaw.cast<String, dynamic>())
          : null,
      history: history,
    );
  }

  static Map<String, dynamic> orderToMap(WaterOrderUi o) {
    return <String, dynamic>{
      'orderId': o.orderId,
      'orderNo': o.orderNo,
      'serviceSubjectName': o.serviceSubjectName,
      'storeName': o.storeName,
      'deviceNo': o.deviceNo,
      'orderStatus': o.orderStatus,
      'orderStatusName': o.orderStatusName,
      'statusRemark': o.statusRemark,
      'warmWaterMl': o.warmWaterMl,
      'waterSeconds': o.waterSeconds,
      'payment': o.payment,
      'payFlag': o.payFlag,
    };
  }

  static WaterOrderUi orderFromMap(Map<String, dynamic> m) {
    return WaterOrderUi(
      orderId: (m['orderId'] ?? '').toString(),
      orderNo: (m['orderNo'] ?? '').toString(),
      serviceSubjectName: (m['serviceSubjectName'] ?? '').toString(),
      storeName: (m['storeName'] ?? '').toString(),
      deviceNo: (m['deviceNo'] ?? '').toString(),
      orderStatus: (m['orderStatus'] ?? '').toString(),
      orderStatusName: (m['orderStatusName'] ?? '').toString(),
      statusRemark: (m['statusRemark'] ?? '').toString(),
      warmWaterMl: _int(m['warmWaterMl']),
      waterSeconds: _int(m['waterSeconds']),
      payment: _double(m['payment']),
      payFlag: _int(m['payFlag']),
    );
  }

  static Map<String, dynamic> historyToMap(WaterOrderHistoryUi h) {
    return <String, dynamic>{
      'orderId': h.orderId,
      'deviceNo': h.deviceNo,
      'status': h.status,
      'payment': h.payment,
      'warmWaterMl': h.warmWaterMl,
      'waterSeconds': h.waterSeconds,
      'completedAt': h.completedAt,
    };
  }

  static WaterOrderHistoryUi historyFromMap(Map<String, dynamic> m) {
    return WaterOrderHistoryUi(
      orderId: (m['orderId'] ?? '').toString(),
      deviceNo: (m['deviceNo'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      payment: _double(m['payment']),
      warmWaterMl: _int(m['warmWaterMl']),
      waterSeconds: _int(m['waterSeconds']),
      completedAt: (m['completedAt'] ?? '').toString(),
    );
  }

  static int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  static double _double(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
}

/// 内存实现：默认兜底 + 测试注入用。无 IO、无平台依赖。
/// 传入非 null [snapshot] 即模拟「已持久化」（load 返回该快照）。
class InMemoryWaterOrderRepository implements WaterOrderRepository {
  InMemoryWaterOrderRepository({WaterOrderSnapshot? snapshot})
      : _snapshot = snapshot;

  WaterOrderSnapshot? _snapshot;

  @override
  Future<WaterOrderSnapshot?> load() async => _snapshot;

  @override
  Future<void> save(WaterOrderSnapshot snapshot) async => _snapshot = snapshot;
}
