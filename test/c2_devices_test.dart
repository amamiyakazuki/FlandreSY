import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/local_device_repository.dart';
import 'package:flandresy/src/data/device_import.dart';
import 'package:flandresy/src/data/adapters/ujing_adapter.dart';
import 'package:flandresy/src/runtime/models/local_device.dart';
import 'package:flandresy/src/runtime/models/washer_order.dart';
import 'package:flandresy/src/runtime/shui_runtime_base.dart';
import 'package:flandresy/src/runtime/live_clock.dart';
import 'support/fake_ujing_adapter.dart';
import 'support/test_runtime.dart';

const qr = 'https://q.ujing.com.cn/u_download.html?uuid=one';
const washer = LocalDeviceShortcut(
    id: 'preset-1',
    customName: '原名',
    deviceType: LocalDeviceType.washer,
    qrUrl: qr);
const water = LocalDeviceShortcut(
    id: 'water-2',
    customName: '饮水',
    deviceType: LocalDeviceType.drinkingWater,
    cd: 'abc');
const hidden = LocalDeviceShortcut(
    id: 'old-3', customName: '旧热水', deviceType: LocalDeviceType.shower798);
const program = WasherProgramUi(
    deviceId: 'one',
    deviceNo: '1',
    deviceTypeName: '洗衣机',
    storeName: '',
    status: '',
    reason: '',
    createOrderEnabled: true,
    defaultWashModelId: 1,
    models: []);

class DelayedUjing extends FakeUjingAdapter {
  final response = Completer<WasherProgramUi>();
  int calls = 0;
  @override
  Future<WasherProgramUi> scanWasher(String qrCode) {
    calls++;
    return response.future;
  }
}

class QueryUjing extends FakeUjingAdapter {
  QueryUjing(this.query);
  final Future<WasherProgramUi> Function(String) query;
  int calls = 0;
  @override
  Future<WasherProgramUi> scanWasher(String qrCode) {
    calls++;
    return query(qrCode);
  }
}

class ControlledDevices extends InMemoryLocalDeviceRepository {
  ControlledDevices(List<LocalDeviceShortcut> initial)
      : super(devices: initial);
  bool fail = false;
  int failAt = 0;
  Completer<void>? gate;
  int calls = 0;
  @override
  Future<void> saveDevices(List<LocalDeviceShortcut> devices) async {
    calls++;
    final pending = gate;
    gate = null;
    if (pending != null) await pending.future;
    if (fail || calls == failAt) throw StateError('disk full');
    await super.saveDevices(devices);
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);
TestRuntime build({LocalDeviceRepository? repo, IUjingAdapter? api}) {
  final runtime = TestRuntime(
      devices: repo ?? InMemoryLocalDeviceRepository(devices: [washer]),
      ujing: api,
      clock: const FixedLiveClock(1700000000000));
  addTearDown(() {
    if (!runtime.isDisposed) runtime.dispose();
  });
  return runtime;
}

Map<String, dynamic> valid() => LocalDeviceCodec.toMap(washer);
void main() {
  test(
      'refresh merges into latest edits and persists without reviving deletion',
      () async {
    final api = DelayedUjing();
    final repo = ControlledDevices([washer, water, hidden]);
    final runtime = build(repo: repo, api: api);
    await runtime.ready;
    final refresh = runtime.refreshLocalDevices();
    await tick();
    await runtime.renameLocalDevice(washer.id, '新名');
    await runtime.deleteLocalDevice(water.id);
    await runtime.addPresetWasherDevice('新增', '$qr-new');
    api.response.complete(program);
    await refresh;
    expect(runtime.state.localDevices.map((d) => d.customName),
        ['新名', '旧热水', '新增']);
    expect(runtime.state.localDevices.first.statusConfirmed, isTrue);
    expect(runtime.state.localDevices.last.statusConfirmed, isFalse);
    expect(LocalDeviceCodec.encode((await repo.loadDevices())!),
        LocalDeviceCodec.encode(runtime.state.localDevices));
    final restored = build(repo: repo);
    await restored.ready;
    expect(restored.state.localDevices.first.customName, '新名');
    expect(restored.state.availableWasherCount, 0);
  });
  for (final readd in [false, true]) {
    test('late query cannot revive deleted/replaced same ID: readd=$readd',
        () async {
      final api = DelayedUjing();
      final runtime = build(api: api);
      await runtime.ready;
      final refresh = runtime.refreshLocalDevices();
      await tick();
      await runtime.deleteLocalDevice(washer.id);
      if (readd) {
        await runtime.confirmDeviceImport(
            runtime.previewDeviceImport(jsonEncode([valid()])));
      }
      api.response.complete(program);
      await refresh;
      expect(runtime.state.localDevices.length, readd ? 1 : 0);
      expect(runtime.state.availableWasherCount, 0);
      expect(runtime.state.localDevicesLastRefreshed, isEmpty);
      expect(runtime.state.devicesRefresh.state, RuntimeTaskState.unavailable);
    });
  }
  test(
      'queued edits calculate from latest committed state and publish only after saving',
      () async {
    final repo = ControlledDevices([washer]);
    final runtime = build(repo: repo);
    await runtime.ready;
    final gate = repo.gate = Completer<void>();
    final rename = runtime.renameLocalDevice(washer.id, '新名');
    await tick();
    final add = runtime.addPresetWasherDevice('新增', '$qr-new');
    await tick();
    expect(repo.calls, 1);
    expect(runtime.state.localDevices.single.customName, '原名');
    gate.complete();
    expect((await rename).success, isTrue);
    expect((await add).success, isTrue);
    expect(runtime.state.localDevices.map((d) => d.customName), ['新名', '新增']);
  });
  test('all edit save failures leave the old list and queue recovers',
      () async {
    final repo = ControlledDevices([washer])..fail = true;
    final runtime = build(repo: repo);
    await runtime.ready;
    final before = LocalDeviceCodec.encode(runtime.state.localDevices);
    final preview =
        runtime.previewDeviceImport(LocalDeviceCodec.encode([water]));
    for (final operation in <Future<DeviceChangeResult> Function()>[
      () => runtime.renameLocalDevice(washer.id, '新名'),
      () => runtime.deleteLocalDevice(washer.id),
      () => runtime.addPresetWasherDevice('新增', '$qr-new'),
      () => runtime.confirmDeviceImport(preview),
    ]) {
      final result = await operation();
      expect(result.success, isFalse);
      expect(result.message, contains('保存失败'));
      expect(LocalDeviceCodec.encode(runtime.state.localDevices), before);
      expect(LocalDeviceCodec.encode((await repo.loadDevices())!), before);
    }
    repo.fail = false;
    expect((await runtime.confirmDeviceImport(preview)).success, isTrue);
    expect(runtime.state.localDevices.single.id, water.id);
  });
  test('import preview includes hidden records and rejects intervening edits',
      () async {
    final api = QueryUjing((_) async => program);
    final runtime = build(repo: ControlledDevices([washer, hidden]), api: api);
    await runtime.ready;
    final preview =
        runtime.previewDeviceImport(LocalDeviceCodec.encode([water]));
    expect(preview.previousCount, 2);
    await runtime.renameLocalDevice(washer.id, '保留');
    expect((await runtime.confirmDeviceImport(preview)).message,
        contains('列表已变化'));
    expect(runtime.state.localDevices.length, 2);
    expect(
        (await runtime.confirmDeviceImport(
                runtime.previewDeviceImport(LocalDeviceCodec.encode([water]))))
            .success,
        isTrue);
    expect(api.calls, 0);
  });
  test(
      'ID suffix and sortOrder both protect allocation after import and restart',
      () async {
    final repo = ControlledDevices([]);
    final runtime = build(repo: repo);
    await runtime.ready;
    await runtime.confirmDeviceImport(runtime.previewDeviceImport(jsonEncode([
      valid()
        ..['id'] = 'preset-900'
        ..['sortOrder'] = 1
    ])));
    await runtime.addPresetWasherDevice('新增', '$qr-new');
    expect(runtime.state.localDevices.last.id, 'preset-901');
    final restored = build(repo: repo);
    await restored.ready;
    await restored.addPresetWasherDevice('再新增', '$qr-other');
    expect(restored.state.localDevices.last.id, 'preset-902');
  });
  testWidgets('notice timeout and edits never release actual refresh lock',
      (tester) async {
    final api = DelayedUjing();
    final runtime = build(api: api);
    await runtime.ready;
    final refresh = runtime.refreshLocalDevices();
    await tester.pump();
    await runtime.renameLocalDevice(washer.id, '新名');
    await tester.pump(const Duration(seconds: 5));
    expect(runtime.state.devicesNotice.message, isNull);
    expect(runtime.state.devicesRefreshing, isTrue);
    await runtime.refreshLocalDevices();
    expect(api.calls, 1);
    api.response.complete(program);
    await refresh;
    expect(runtime.state.devicesRefreshing, isFalse);
  });
  test(
      'partial success, full failure and recovery have honest totals/time/counts',
      () async {
    var failAll = false;
    final api = QueryUjing((code) async {
      if (failAll || code.endsWith('two')) throw StateError('offline');
      return program;
    });
    final runtime = build(
        repo: ControlledDevices([
          washer,
          const LocalDeviceShortcut(
              id: 'b',
              customName: 'B',
              deviceType: LocalDeviceType.washer,
              qrUrl: '${qr}two'),
          water
        ]),
        api: api);
    await runtime.ready;
    await runtime.refreshLocalDevices();
    expect(
        runtime.state.devicesRefresh.message, contains('成功 1 条，失败 1 条，跳过 1 条'));
    expect(runtime.state.availableWasherCount, 1);
    final at = runtime.state.localDevicesLastRefreshed;
    expect(at, isNotEmpty);
    failAll = true;
    await runtime.refreshLocalDevices();
    expect(runtime.state.availableWasherCount, 0);
    expect(runtime.state.localDevices.first.lastStatus, '可下单');
    expect(runtime.state.localDevices.first.statusQueryFailed, isTrue);
    expect(runtime.state.localDevicesLastRefreshed, at);
    failAll = false;
    await runtime.refreshLocalDevices();
    expect(runtime.state.localDevices.first.statusQueryFailed, isFalse);
    expect(runtime.state.availableWasherCount, 1);
  });
  test('zero queries and failed refresh save do not report success', () async {
    final repo = ControlledDevices([water]);
    final runtime = build(repo: repo, api: QueryUjing((_) async => program));
    await runtime.ready;
    await runtime.refreshLocalDevices();
    expect(runtime.state.devicesRefresh.state, RuntimeTaskState.unavailable);
    expect(runtime.state.localDevicesLastRefreshed, isEmpty);
    await runtime.addPresetWasherDevice('洗衣', qr);
    repo.fail = true;
    await runtime.refreshLocalDevices();
    expect(runtime.state.devicesRefresh.message, contains('保存失败'));
    expect(runtime.state.localDevicesLastRefreshed, isEmpty);
    expect(runtime.state.availableWasherCount, 0);
    expect(runtime.state.localDevices.last.lastStatus, isNull);
  });
  for (final action in ['login', 'logout', 'dispose']) {
    test('late refresh ignored after $action', () async {
      final api = DelayedUjing();
      final runtime = build(api: api);
      await runtime.ready;
      final refresh = runtime.refreshLocalDevices();
      await tick();
      if (action == 'login') runtime.beginUjingLoginEpoch();
      if (action == 'logout') {
        await runtime.handleAuthInvalidation(AuthService.ujing,
            localLogout: true);
      }
      if (action == 'dispose') runtime.dispose();
      api.response.complete(program);
      await refresh;
      expect(runtime.state.localDevices.single.lastStatus, isNull);
      expect(runtime.state.availableWasherCount, 0);
      if (action != 'dispose') expect(runtime.state.devicesRefreshing, isFalse);
    });
  }
  test('auth invalid exception stops batch and clears availability', () async {
    final runtime = build(
        api: QueryUjing((_) async =>
            throw const UjingException('expired', authInvalid: true)));
    await runtime.ready;
    await runtime.refreshLocalDevices();
    expect(runtime.state.devicesRefresh.state, RuntimeTaskState.loginRequired);
    expect(runtime.state.devicesRefreshing, isFalse);
    expect(runtime.state.localDevices.length, 1);
  });
  test(
      'legacy hidden, empty and duplicate IDs preserved, ambiguous edits blocked',
      () async {
    final legacy = LocalDeviceCodec.decode(jsonEncode([
      valid(),
      valid(),
      {'id': '', 'deviceType': 'unknown'},
      LocalDeviceCodec.toMap(hidden)
    ]));
    final api = QueryUjing((_) async => program);
    final runtime = build(repo: ControlledDevices(legacy), api: api);
    await runtime.ready;
    expect(
        (await runtime.renameLocalDevice(washer.id, 'wrong')).success, isFalse);
    expect((await runtime.deleteLocalDevice('')).success, isFalse);
    await runtime.refreshLocalDevices();
    expect(api.calls, 0);
    expect(runtime.state.localDevices.length, 4);
    await runtime.addPresetWasherDevice('新', '$qr-new');
    expect(runtime.state.localDevices.take(4).map((d) => d.id),
        legacy.map((d) => d.id));
  });
  test('auth change while disk save pending cannot restore confidence',
      () async {
    final repo = ControlledDevices([washer]);
    final runtime = build(repo: repo, api: QueryUjing((_) async => program));
    await runtime.ready;
    await runtime.refreshLocalDevices();
    final gate = repo.gate = Completer<void>();
    final rename = runtime.renameLocalDevice(washer.id, '新名');
    await tick();
    runtime.beginUjingLoginEpoch();
    gate.complete();
    await rename;
    expect(runtime.state.availableWasherCount, 0);
    expect(runtime.state.localDevices.single.customName, '新名');
  });

  test('old menu identity cannot edit a replacement with the same ID',
      () async {
    final runtime = build();
    await runtime.ready;
    final original = runtime.state.localDevices.single;
    await runtime.confirmDeviceImport(
        runtime.previewDeviceImport(jsonEncode([valid()])));
    expect(
        (await runtime.renameLocalDevice(washer.id, '错误名称',
                expectedIncarnation: original.incarnation))
            .success,
        isFalse);
    expect(
        (await runtime.deleteLocalDevice(washer.id,
                expectedIncarnation: original.incarnation))
            .success,
        isFalse);
    expect(runtime.state.localDevices.single.customName, '原名');
  });
  testWidgets('old success timer cannot erase a later shared-save error',
      (tester) async {
    final runtime = build();
    await runtime.ready;
    await runtime.renameLocalDevice(washer.id, '新名');
    runtime.emit(runtime.state.copyWith(
        devicesNotice: const RuntimeActionStatus(
            state: RuntimeTaskState.failure, message: '关水已确认，本地保存失败')));
    await tester.pump(const Duration(seconds: 5));
    expect(runtime.state.devicesNotice.message, contains('本地保存失败'));
  });
  test(
      'scanner adds water, rejects empty code and duplicates without losing records',
      () async {
    final runtime = build();
    await runtime.ready;
    expect(
        (await runtime
                .addScannedDeviceFromQr('https://q.ujing.com.cn/ed?cd=water'))
            .success,
        isTrue);
    expect(
        (await runtime.addScannedDeviceFromQr('https://q.ujing.com.cn/ed?cd='))
            .success,
        isFalse);
    expect(
        (await runtime
                .addScannedDeviceFromQr('https://q.ujing.com.cn/ed?cd=water'))
            .success,
        isFalse);
    expect(runtime.state.localDevices.length, 2);
    expect(runtime.state.localDevices.last.cd, 'water');
  });
  test(
      'replacement discards previous refresh timestamp and imported cache confidence',
      () async {
    final runtime = build(api: QueryUjing((_) async => program));
    await runtime.ready;
    await runtime.refreshLocalDevices();
    expect(runtime.state.availableWasherCount, 1);
    await runtime.confirmDeviceImport(runtime.previewDeviceImport(
        LocalDeviceCodec.encode(runtime.state.localDevices)));
    expect(runtime.state.localDevicesLastRefreshed, isEmpty);
    expect(runtime.state.availableWasherCount, 0);
    expect(runtime.state.localDevices.single.lastStatus, '可下单');
  });

  final invalid = <String, Object>{
    'empty object': [{}],
    'empty list': [],
    'wrong root': {},
    'numeric ID': [valid()..['id'] = 1],
    'empty ID': [valid()..['id'] = ' '],
    'duplicate ID': [valid(), valid()..['qrUrl'] = '$qr-new'],
    'duplicate QR': [
      valid(),
      valid()
        ..['id'] = 'other'
        ..['qrUrl'] = ' $qr '
    ],
    'duplicate cd': [
      LocalDeviceCodec.toMap(water),
      LocalDeviceCodec.toMap(water)
        ..['id'] = 'other'
        ..['cd'] = ' abc '
    ],
    'unknown': [valid()..['deviceType'] = 'unknown'],
    'hidden': [LocalDeviceCodec.toMap(hidden)],
    'new enum': [valid()..['deviceType'] = 'xyz'],
    'missing QR': [valid()..remove('qrUrl')],
    'empty UUID': [
      valid()..['qrUrl'] = 'https://q.ujing.com.cn/u_download.html?uuid='
    ],
    'fake path': [valid()..['qrUrl'] = 'https://example.invalid/uuid=one'],
    'missing cd': [LocalDeviceCodec.toMap(water)..['cd'] = ' '],
    'name type': [valid()..['customName'] = 9],
    'text type': [valid()..['storeName'] = {}],
    'negative sort': [valid()..['sortOrder'] = -1],
    'decimal sort': [valid()..['sortOrder'] = 1.5],
    'null sort': [valid()..['sortOrder'] = null],
    'bad sort string': [valid()..['sortOrder'] = 'one'],
  };
  for (final entry in invalid.entries) {
    test('strict import rejects ${entry.key}', () {
      expect(() => DeviceImport.parse(jsonEncode(entry.value)),
          throwsFormatException);
    });
  }
  test('compatible exports parse without trusting cache or unknown fields', () {
    final parsed = DeviceImport.parse(jsonEncode([
      valid()
        ..['id'] = ' a '
        ..['sortOrder'] = '2'
        ..['customName'] = ''
        ..['lastStatus'] = '可下单'
        ..['statusConfirmed'] = true,
      LocalDeviceCodec.toMap(water)..['sortOrder'] = 2
    ]));
    expect(parsed.map((d) => d.id), ['a', water.id]);
    expect(parsed.first.statusConfirmed, isFalse);
    expect(parsed.first.statusCheckedAt, isEmpty);
    expect(DeviceImport.parse(LocalDeviceCodec.encode(parsed)).length, 2);
  });
}
