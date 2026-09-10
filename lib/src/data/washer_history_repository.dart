import 'dart:convert';

import '../runtime/models/washer_order.dart';

abstract class WasherHistoryRepository {
  Future<List<WasherOrderHistoryUi>?> loadHistory();
  Future<void> saveHistory(List<WasherOrderHistoryUi> history);
}

class WasherHistoryCodec {
  const WasherHistoryCodec._();

  static String encode(List<WasherOrderHistoryUi> history) => jsonEncode(
        history
            .map((item) => <String, dynamic>{
                  'orderId': item.orderId,
                  'deviceNo': item.deviceNo,
                  'status': item.status,
                  'statusText': item.statusText,
                  'payPrice': item.payPrice,
                })
            .toList(),
      );

  static List<WasherOrderHistoryUi> decode(String json) {
    if (json.isEmpty) return const <WasherOrderHistoryUi>[];
    final value = jsonDecode(json);
    if (value is! List) return const <WasherOrderHistoryUi>[];
    return [
      for (final item in value)
        if (item is Map)
          WasherOrderHistoryUi(
            orderId: '${item['orderId'] ?? ''}',
            deviceNo: '${item['deviceNo'] ?? ''}',
            status: '${item['status'] ?? ''}',
            statusText: '${item['statusText'] ?? ''}',
            payPrice: '${item['payPrice'] ?? ''}',
          ),
    ];
  }
}

class InMemoryWasherHistoryRepository implements WasherHistoryRepository {
  InMemoryWasherHistoryRepository({List<WasherOrderHistoryUi>? history})
      : _history = history;

  List<WasherOrderHistoryUi>? _history;

  @override
  Future<List<WasherOrderHistoryUi>?> loadHistory() async => _history;

  @override
  Future<void> saveHistory(List<WasherOrderHistoryUi> history) async {
    _history = List<WasherOrderHistoryUi>.of(history);
  }
}
