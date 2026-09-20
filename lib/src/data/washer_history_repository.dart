import 'dart:convert';

import '../runtime/models/washer_order.dart';

abstract class WasherHistoryRepository {
  Future<List<WasherOrderHistoryUi>?> loadHistory();
  Future<void> saveHistory(List<WasherOrderHistoryUi> history);
  Future<WasherOrderUi?> loadCurrentOrder();
  Future<void> saveSnapshot(
      {WasherOrderUi? currentOrder,
      required List<WasherOrderHistoryUi> history});
}

class WasherHistoryCodec {
  const WasherHistoryCodec._();

  static WasherOrderUi? legacyCandidate(List<WasherOrderHistoryUi> history) {
    for (final item in history) {
      if (item.ownerAccountKey.isEmpty &&
          item.status != '50' &&
          item.status != 'cancelled') {
        return WasherOrderUi(
            orderId: item.orderId,
            deviceNo: item.deviceNo,
            statusText: '旧版本订单，待确认所属账号',
            payPrice: item.payPrice,
            status: 'pending');
      }
    }
    return null;
  }

  static String encode(List<WasherOrderHistoryUi> history) => jsonEncode(
        history
            .map((item) => <String, dynamic>{
                  'orderId': item.orderId,
                  'ownerAccountKey': item.ownerAccountKey,
                  'deviceNo': item.deviceNo,
                  'status': item.status,
                  'statusText': item.statusText,
                  'payPrice': item.payPrice,
                })
            .toList(),
      );

  static List<WasherOrderHistoryUi> decode(String json) {
    if (json.isEmpty) throw const FormatException('洗衣历史为空');
    final value = jsonDecode(json);
    if (value is! List) throw const FormatException('洗衣历史不是列表');
    for (final item in value) {
      if (item is! Map) throw const FormatException('洗衣历史记录损坏');
      _validateRecord(item);
    }
    return [
      for (final item in value)
        if (item is Map)
          WasherOrderHistoryUi(
            orderId: '${item['orderId'] ?? ''}',
            ownerAccountKey: '${item['ownerAccountKey'] ?? ''}',
            deviceNo: '${item['deviceNo'] ?? ''}',
            status: '${item['status'] ?? ''}',
            statusText: '${item['statusText'] ?? ''}',
            payPrice: '${item['payPrice'] ?? ''}',
          ),
    ];
  }

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
      };

  static WasherOrderUi orderFromMap(Map m) {
    _validateRecord(m);
    return WasherOrderUi(
      orderId: '${m['orderId'] ?? ''}',
      deviceNo: '${m['deviceNo'] ?? ''}',
      statusText: '${m['statusText'] ?? ''}',
      payPrice: '${m['payPrice'] ?? ''}',
      status: '${m['status'] ?? ''}',
      ownerAccountKey: '${m['ownerAccountKey'] ?? ''}',
      remainTimeSeconds: int.tryParse('${m['remainTimeSeconds']}') ?? 0,
      countDownSeconds: int.tryParse('${m['countDownSeconds']}') ?? 0,
      refreshedAtMillis: int.tryParse('${m['refreshedAtMillis']}') ?? 0,
    );
  }

  static void _validateRecord(Map m) {
    if (m['orderId'] is! String ||
        (m['orderId'] as String).trim().isEmpty ||
        (m.containsKey('ownerAccountKey') && m['ownerAccountKey'] is! String)) {
      throw const FormatException('洗衣订单标识或归属损坏');
    }
  }
}

class InMemoryWasherHistoryRepository implements WasherHistoryRepository {
  InMemoryWasherHistoryRepository(
      {List<WasherOrderHistoryUi>? history, WasherOrderUi? currentOrder})
      : _history = history,
        _currentOrder = currentOrder;

  List<WasherOrderHistoryUi>? _history;
  WasherOrderUi? _currentOrder;

  @override
  Future<WasherOrderUi?> loadCurrentOrder() async =>
      _currentOrder ?? WasherHistoryCodec.legacyCandidate(_history ?? const []);

  @override
  Future<void> saveSnapshot(
      {WasherOrderUi? currentOrder,
      required List<WasherOrderHistoryUi> history}) async {
    _currentOrder = currentOrder;
    _history = List.of(history);
  }

  @override
  Future<List<WasherOrderHistoryUi>?> loadHistory() async => _history;

  @override
  Future<void> saveHistory(List<WasherOrderHistoryUi> history) async {
    _history = List<WasherOrderHistoryUi>.of(history);
  }
}
