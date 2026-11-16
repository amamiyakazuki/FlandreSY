import 'dart:convert';

import '../runtime/models/washer_order.dart';

/// 洗衣订单本地快照：各账号进行中的订单 + 已结束历史。
class WasherSnapshot {
  const WasherSnapshot({
    this.orders = const <WasherOrderUi>[],
    this.history = const <WasherOrderHistoryUi>[],
  });

  final List<WasherOrderUi> orders;
  final List<WasherOrderHistoryUi> history;
}

abstract class WasherHistoryRepository {
  /// null = 从未保存过。
  Future<WasherSnapshot?> load();
  Future<void> save(WasherSnapshot snapshot);
}

class WasherHistoryCodec {
  const WasherHistoryCodec._();

  static String encode(WasherSnapshot snapshot) => jsonEncode({
        'version': 2,
        'orders': snapshot.orders.map(orderToMap).toList(),
        'history': snapshot.history.map(historyToMap).toList(),
      });

  /// 兼容旧格式：`currentOrder`（单笔）+ `history`，或更早的纯历史数组。
  /// 单条记录损坏只跳过该条，不让整份数据失效。
  static WasherSnapshot decode(String raw) {
    final value = jsonDecode(raw);
    if (value is List) {
      return WasherSnapshot(history: _historyList(value));
    }
    if (value is! Map) throw const FormatException('洗衣订单数据不是对象');
    final orders = <WasherOrderUi>[];
    final rawOrders = value['orders'];
    if (rawOrders is List) {
      for (final item in rawOrders) {
        final order = item is Map ? _tryOrder(item) : null;
        if (order != null) orders.add(order);
      }
    }
    final legacyCurrent = value['currentOrder'];
    if (legacyCurrent is Map) {
      final order = _tryOrder(legacyCurrent);
      if (order != null && !order.isTerminal) orders.add(order);
    }
    final rawHistory = value['history'];
    return WasherSnapshot(
      orders: orders,
      history: rawHistory is List ? _historyList(rawHistory) : const [],
    );
  }

  static List<WasherOrderHistoryUi> _historyList(List raw) => [
        for (final item in raw)
          if (item is Map && _hasId(item)) historyFromMap(item),
      ];

  static WasherOrderUi? _tryOrder(Map m) => _hasId(m) ? orderFromMap(m) : null;

  static bool _hasId(Map m) => '${m['orderId'] ?? ''}'.trim().isNotEmpty;

  static Map<String, dynamic> orderToMap(WasherOrderUi o) => {
        'orderId': o.orderId,
        'deviceNo': o.deviceNo,
        'statusText': o.statusText,
        'payPrice': o.payPrice,
        'status': o.status,
        'remainTimeSeconds': o.remainTimeSeconds,
        'countDownSeconds': o.countDownSeconds,
        'refreshedAtMillis': o.refreshedAtMillis,
        'ownerAccountKey': o.ownerAccountKey,
        'createdAtMillis': o.createdAtMillis,
        'autoStart': o.autoStart,
        'endsAtMillis': o.endsAtMillis,
      };

  static WasherOrderUi orderFromMap(Map m) {
    final status = _str(m['status']);
    final remain = _int(m['remainTimeSeconds']);
    final refreshedAt = _int(m['refreshedAtMillis']);
    // 旧数据没有预计结束时间时，按保存时的剩余时间补算。
    final endsAt = m.containsKey('endsAtMillis')
        ? _int(m['endsAtMillis'])
        : WasherOrderUi.expectedEndsAt(status, remain, refreshedAt, 0);
    return WasherOrderUi(
      orderId: '${m['orderId']}',
      deviceNo: _str(m['deviceNo']),
      statusText: _str(m['statusText']),
      payPrice: _str(m['payPrice']),
      status: status,
      ownerAccountKey: _str(m['ownerAccountKey']),
      remainTimeSeconds: remain,
      countDownSeconds: _int(m['countDownSeconds']),
      refreshedAtMillis: refreshedAt,
      createdAtMillis: _int(m['createdAtMillis']),
      autoStart: m['autoStart'] == true,
      endsAtMillis: endsAt,
    );
  }

  static Map<String, dynamic> historyToMap(WasherOrderHistoryUi h) => {
        'orderId': h.orderId,
        'ownerAccountKey': h.ownerAccountKey,
        'deviceNo': h.deviceNo,
        'status': h.status,
        'statusText': h.statusText,
        'payPrice': h.payPrice,
        'createdAtMillis': h.createdAtMillis,
      };

  static WasherOrderHistoryUi historyFromMap(Map m) => WasherOrderHistoryUi(
        orderId: '${m['orderId']}',
        ownerAccountKey: _str(m['ownerAccountKey']),
        deviceNo: _str(m['deviceNo']),
        status: _str(m['status']),
        statusText: _str(m['statusText']),
        payPrice: _str(m['payPrice']),
        createdAtMillis: _int(m['createdAtMillis']),
      );

  static String _str(Object? v) => v == null ? '' : '$v';
  static int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
}

class InMemoryWasherHistoryRepository implements WasherHistoryRepository {
  InMemoryWasherHistoryRepository({WasherSnapshot? snapshot})
      : _snapshot = snapshot;

  WasherSnapshot? _snapshot;

  @override
  Future<WasherSnapshot?> load() async => _snapshot;

  @override
  Future<void> save(WasherSnapshot snapshot) async => _snapshot = snapshot;
}
