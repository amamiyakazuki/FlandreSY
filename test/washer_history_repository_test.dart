import 'package:flandresy/src/data/app_bootstrap.dart';
import 'package:flandresy/src/data/washer_history_repository.dart';
import 'support/test_runtime.dart';
import 'package:flandresy/src/runtime/models/washer_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const record = WasherOrderHistoryUi(
    orderId: 'washer-1',
    deviceNo: 'A-08',
    status: '50',
    statusText: '已完成',
    payPrice: '¥3.50',
    ownerAccountKey: 'A',
    createdAtMillis: 1700000000000,
  );
  const active = WasherOrderUi(
    orderId: 'washer-2',
    deviceNo: 'A-09',
    statusText: '已预约',
    payPrice: '¥2.10',
    status: '20',
    ownerAccountKey: 'B',
    createdAtMillis: 1700000001000,
    autoStart: true,
  );

  test('codec round-trips active orders and history', () {
    final decoded = WasherHistoryCodec.decode(WasherHistoryCodec.encode(
        const WasherSnapshot(orders: [active], history: [record])));
    expect(decoded.history.single.orderId, record.orderId);
    expect(decoded.history.single.statusText, record.statusText);
    expect(decoded.history.single.createdAtMillis, record.createdAtMillis);
    final order = decoded.orders.single;
    expect(order.orderId, active.orderId);
    expect(order.ownerAccountKey, 'B');
    expect(order.autoStart, isTrue);
    expect(order.createdAtMillis, active.createdAtMillis);
  });

  test('old single currentOrder format is read as one active order', () {
    final decoded = WasherHistoryCodec.decode(
        '{"currentOrder":{"orderId":"old","status":"10","ownerAccountKey":"A"},'
        '"history":[{"orderId":"h","status":"50","needsRecovery":true}]}');
    expect(decoded.orders.single.orderId, 'old');
    expect(decoded.history.single.orderId, 'h');
  });

  test('a damaged record is skipped instead of failing the whole snapshot', () {
    final decoded = WasherHistoryCodec.decode(
        '{"orders":[{"status":"10"},{"orderId":"ok","status":"10"}],'
        '"history":[42,{"orderId":"h"}]}');
    expect(decoded.orders.single.orderId, 'ok');
    expect(decoded.history.single.orderId, 'h');
  });

  test('restored washer history survives leaving washer flow', () async {
    final runtime = TestRuntime(
      initial: const PersistedSnapshot(
        bathSystem: BathSystemPreference.none,
        washerHistory: [record],
      ),
    );
    addTearDown(runtime.dispose);

    await runtime.ready;
    expect(runtime.state.washer.history.single.orderId, 'washer-1');

    runtime.resetWasherTransient();
    expect(runtime.state.washer.history.single.orderId, 'washer-1');
  });
}
