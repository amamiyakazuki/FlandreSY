import 'package:flandresy/src/data/app_bootstrap.dart';
import 'package:flandresy/src/data/washer_history_repository.dart';
import 'package:flandresy/src/runtime/fake_shui_runtime.dart';
import 'package:flandresy/src/runtime/models/washer_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const record = WasherOrderHistoryUi(
    orderId: 'washer-1',
    deviceNo: 'A-08',
    status: '50',
    statusText: '已完成',
    payPrice: '¥3.50',
  );

  test('washer history codec preserves all displayed fields', () {
    final decoded = WasherHistoryCodec.decode(
      WasherHistoryCodec.encode(const [record]),
    );

    expect(decoded, hasLength(1));
    expect(decoded.single.orderId, record.orderId);
    expect(decoded.single.deviceNo, record.deviceNo);
    expect(decoded.single.status, record.status);
    expect(decoded.single.statusText, record.statusText);
    expect(decoded.single.payPrice, record.payPrice);
  });

  test('restored washer history survives leaving washer flow', () async {
    final runtime = FakeShuiRuntime(
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

  test('creating a washer order writes its history repository', () async {
    final repository = InMemoryWasherHistoryRepository();
    final runtime = FakeShuiRuntime(
      washerHistory: repository,
      initial: const PersistedSnapshot(
        bathSystem: BathSystemPreference.none,
      ),
    );
    addTearDown(runtime.dispose);

    await runtime.ready;
    await runtime.scanWasher('washer-code');
    final model = runtime.state.washer.program!.models.first;
    await runtime.createWasherOrder(
      washModelId: model.id,
      temperatureId: 1,
    );

    final saved = await repository.loadHistory();
    expect(saved, hasLength(1));
    expect(saved!.single.orderId, runtime.state.washer.history.single.orderId);
    expect(saved.single.payPrice, runtime.state.washer.history.single.payPrice);
  });
}
