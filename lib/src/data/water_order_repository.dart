// Drinking-water order persistence abstraction (no visual constants). Same decoupling pattern as
// HistoryRepository (PHIST) / LocalDeviceRepository (PDEV). PWATER (Phase 3 问题7): the current
// water order (state.currentWaterOrder) + completed history (state.waterHistory) previously lived
// only in memory → an app restart dropped them, so 订单页饮水分类 went empty even after 接水.
// Now both round-trip through this repository: 创建即记录当前订单，完成转历史，重启恢复。

import 'dart:convert';

import '../runtime/models/water_order.dart';

/// 饮水订单本地快照：各账号进行中的订单（每个账号至多一笔）+ 已完成历史。
class WaterOrderSnapshot {
  const WaterOrderSnapshot({
    this.orders = const <WaterOrderUi>[],
    this.history = const <WaterOrderHistoryUi>[],
  });

  final List<WaterOrderUi> orders;
  final List<WaterOrderHistoryUi> history;
}

/// 饮水订单持久化接口。[load] 返回 null 表示从未保存过。
abstract class WaterOrderRepository {
  Future<WaterOrderSnapshot?> load();
  Future<void> save(WaterOrderSnapshot snapshot);
}

/// 饮水订单 JSON 编解码。兼容旧格式的单笔 `currentOrder`；
/// 单条记录损坏只跳过该条，不让整份数据失效。
class WaterOrderCodec {
  const WaterOrderCodec._();

  static String encode(WaterOrderSnapshot snapshot) {
    return jsonEncode(<String, dynamic>{
      'version': 2,
      'orders': snapshot.orders.map(orderToMap).toList(),
      'history': snapshot.history.map(historyToMap).toList(),
    });
  }

  static WaterOrderSnapshot decode(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw const FormatException('饮水订单快照不是对象');
    }
    final orders = <WaterOrderUi>[];
    final rawOrders = decoded['orders'];
    if (rawOrders is List) {
      for (final item in rawOrders) {
        if (item is Map && _hasId(item)) orders.add(orderFromMap(item));
      }
    }
    final legacyCurrent = decoded['currentOrder'];
    if (legacyCurrent is Map && _hasId(legacyCurrent)) {
      orders.add(orderFromMap(legacyCurrent));
    }
    final rawHistory = decoded['history'];
    return WaterOrderSnapshot(
      orders: orders,
      history: [
        if (rawHistory is List)
          for (final item in rawHistory)
            if (item is Map && _hasId(item)) historyFromMap(item),
      ],
    );
  }

  static bool _hasId(Map m) => '${m['orderId'] ?? ''}'.trim().isNotEmpty;

  static Map<String, dynamic> orderToMap(WaterOrderUi o) {
    return <String, dynamic>{
      'orderId': o.orderId,
      'ownerAccountKey': o.ownerAccountKey,
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
      'createdAtMillis': o.createdAtMillis,
    };
  }

  static WaterOrderUi orderFromMap(Map m) {
    return WaterOrderUi(
      orderId: (m['orderId'] ?? '').toString(),
      ownerAccountKey: (m['ownerAccountKey'] ?? '').toString(),
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
      createdAtMillis: _int(m['createdAtMillis']),
    );
  }

  static Map<String, dynamic> historyToMap(WaterOrderHistoryUi h) {
    return <String, dynamic>{
      'orderId': h.orderId,
      'ownerAccountKey': h.ownerAccountKey,
      'deviceNo': h.deviceNo,
      'status': h.status,
      'payment': h.payment,
      'warmWaterMl': h.warmWaterMl,
      'waterSeconds': h.waterSeconds,
      'completedAt': h.completedAt,
      'completedAtMillis': h.completedAtMillis,
    };
  }

  static WaterOrderHistoryUi historyFromMap(Map m) {
    return WaterOrderHistoryUi(
      ownerAccountKey: (m['ownerAccountKey'] ?? '').toString(),
      orderId: (m['orderId'] ?? '').toString(),
      deviceNo: (m['deviceNo'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      payment: _double(m['payment']),
      warmWaterMl: _int(m['warmWaterMl']),
      waterSeconds: _int(m['waterSeconds']),
      completedAt: (m['completedAt'] ?? '').toString(),
      completedAtMillis: _int(m['completedAtMillis']),
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
