import 'package:flandresy/src/data/adapters/hotwater_adapter.dart';
import 'package:flandresy/src/data/adapters/real_zhuli_adapter.dart';
import 'package:flandresy/src/data/adapters/zhuli_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const session = ZhuliSessionData(
    platformToken: 'platform-token',
    userId: 'staff-1',
    identityCode: 'identity',
    serverAddr: 'https://example.com',
    serverAppId: 'server-app',
    serverId: 'server-id',
    secretKey: 'secret',
  );

  test('loadHistory sends the complete local 30-day time range', () async {
    final transport = _RecordingZhuliTransport(rows: const [
      {
        'create_at': '2026-09-09 20:30:40',
        'device_id': 'device-7',
        'consume_money': '1.2',
        'status': '已完成',
        'order_id': 'order-9',
      },
    ]);
    final adapter = RealZhuliAdapter(
      transport: transport,
      session: session,
      now: () => DateTime(2026, 9, 10, 8, 7, 6),
      nonce: () => 'nonce',
      timestamp: () => 'timestamp',
    );

    final history = await adapter.loadHistory();

    final request = transport.lastArrayRequest;
    expect(request, isNotNull);
    expect(request!.url, endsWith('/consume/list_record_by_staffid'));
    expect(request.params['staff_id'], 'staff-1');
    expect(request.params['start'], '2026-08-11 08:07:06');
    expect(request.params['end'], '2026-09-10 08:07:06');
    expect(request.params['start'], isNotEmpty);
    expect(request.params['end'], isNotEmpty);
    expect(history, hasLength(1));
    expect(history.single.time, '2026-09-09 20:30:40');
    expect(history.single.deviceId, 'device-7');
    expect(history.single.amount, '¥1.20');
    expect(history.single.status, '已完成');
    expect(history.single.orderId, 'order-9');
  });

  test('loadHistory does not disguise missing values as zero or completed',
      () async {
    final adapter = RealZhuliAdapter(
      transport: _RecordingZhuliTransport(rows: const [<String, dynamic>{}]),
      session: session,
      now: () => DateTime(2026, 9, 10),
    );

    final history = await adapter.loadHistory();

    expect(history.single.amount, '金额未知');
    expect(history.single.status, '状态未知');
  });

  test('business failure log identifies endpoint and code only', () async {
    final logs = <String>[];
    final adapter = RealZhuliAdapter(
      transport: _RecordingZhuliTransport(
        arrayError: const HotwaterException(
          'response contains sensitive details',
          code: 'error_args',
        ),
      ),
      session: session,
      now: () => DateTime(2026, 9, 10),
      log: logs.add,
    );

    await expectLater(
      adapter.loadHistory(),
      throwsA(isA<HotwaterException>()),
    );

    expect(logs, [
      '住理接口失败 endpoint=consume/list_record_by_staffid code=error_args',
    ]);
    expect(logs.single, isNot(contains('sensitive')));
  });
}

class _RecordingZhuliTransport implements ZhuliTransport {
  _RecordingZhuliTransport({this.arrayError, this.rows = const []});

  final HotwaterException? arrayError;
  final List<dynamic> rows;
  ZhuliRequest? lastArrayRequest;

  @override
  Future<List<dynamic>> getArray(ZhuliRequest request) async {
    lastArrayRequest = request;
    final error = arrayError;
    if (error != null) {
      throw error;
    }
    return rows;
  }

  @override
  Future<Map<String, dynamic>> getObject(ZhuliRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<String> getString(ZhuliRequest request) {
    throw UnimplementedError();
  }
}
