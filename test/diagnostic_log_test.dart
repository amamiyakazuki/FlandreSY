import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/diagnostic_log_repository.dart';
import 'package:flandresy/src/runtime/diagnostic_log.dart';

Future<void> tick() => Future<void>.delayed(Duration.zero);

class DelayedLogRepo implements DiagnosticLogRepository {
  String stored = '';
  Completer<String>? loading;
  Completer<void>? saving;
  bool fail = false;
  @override
  Future<String> load() async =>
      loading == null ? stored : await loading!.future;
  @override
  Future<void> save(String value) async {
    if (saving != null) {
      final gate = saving!;
      saving = null;
      await gate.future;
    }
    if (fail) throw StateError('synthetic-private-value');
    stored = value;
  }
}

void main() {
  test('clear waits for storage and queued old saves cannot revive logs',
      () async {
    final repo = DelayedLogRepo();
    final log = DiagnosticLog(repo: repo);
    await tick();
    final gate = Completer<void>();
    repo.saving = gate;
    log.log('ujing', 'U净登录成功');
    await tick();
    var cleared = false;
    final clear = Future<void>.sync(log.clear).then((_) => cleared = true);
    await tick();
    expect(cleared, isFalse);
    gate.complete();
    await clear;
    await tick();
    expect(repo.stored, isEmpty);
    expect(log.read(), isEmpty);
  });
  test('clear invalidates a late restore', () async {
    final repo = DelayedLogRepo()..loading = Completer<String>();
    final log = DiagnosticLog(repo: repo);
    final clear = Future<void>.sync(log.clear);
    repo.loading!.complete('[12:00:00] [ujing] U净登录成功\n');
    await clear;
    await tick();
    expect(log.read(), isEmpty);
    expect(repo.stored, isEmpty);
  });
  test('diagnostics never retain raw secrets', () async {
    final log = DiagnosticLog(repo: InMemoryDiagnosticLogRepository());
    log.log('ujing', 'mobile=13912345678 token=SYNTHETIC_TOKEN');
    log.log('flutter-error', 'https://local.invalid/?sign=SYNTHETIC_SIGN');
    expect(log.read(), isNot(contains('13912345678')));
    expect(log.read(), isNot(contains('SYNTHETIC')));
  });
  test(
      'new events survive clear and duplicate clears preserve their boundaries',
      () async {
    final repo = DelayedLogRepo();
    final log = DiagnosticLog(repo: repo);
    await log.ready;
    log.log('ujing', 'U净登录成功');
    await log.flush();
    final gate = Completer<void>();
    repo.saving = gate;
    final first = log.clear();
    await tick();
    log.log('hotwater', '住理登录成功');
    final second = log.clear();
    log.log('shower798', '798 洗浴登录成功');
    gate.complete();
    await Future.wait([first, second]);
    await log.flush();
    expect(log.read(), isNot(contains('U净登录成功')));
    expect(log.read(), isNot(contains('住理登录成功')));
    expect(log.read(), contains('798 洗浴登录成功'));
    expect(repo.stored, log.read());
    final restarted = DiagnosticLog(repo: repo);
    await restarted.ready;
    expect(restarted.read(), log.read());
  });
  test('failed clear retains log and later append and retry still work',
      () async {
    final repo = DelayedLogRepo();
    final log = DiagnosticLog(repo: repo);
    await log.ready;
    log.log('ujing', 'U净登录成功');
    await log.flush();
    final before = log.read();
    repo.fail = true;
    await expectLater(log.clear(), throwsStateError);
    expect(log.read(), before);
    expect(repo.stored, before);
    expect(log.storageError, isNotNull);
    log.log('hotwater', '住理登录成功');
    await log.flush();
    expect(log.read(), contains('住理登录成功'));
    repo.fail = false;
    await log.clear();
    expect(log.storageError, isNull);
    expect(log.read(), isEmpty);
    expect(repo.stored, isEmpty);
    log.log('ujing', 'U净登录成功');
    await log.flush();
    expect(repo.stored, log.read());
  });
  test('slow restore merges before newer entries and sanitizes before persist',
      () async {
    final repo = DelayedLogRepo()..loading = Completer<String>();
    final log = DiagnosticLog(repo: repo);
    log.log('hotwater', '住理登录成功');
    repo.loading!.complete(
        '[12:00:00] [ujing] U净登录成功\n[12:00:01] [auth] token=PRIVATE\n');
    await log.ready;
    await log.flush();
    expect(log.read(), contains('U净登录成功'));
    expect(log.read(), contains('住理登录成功'));
    expect(log.read().indexOf('U净'), lessThan(log.read().indexOf('住理')));
    expect(log.read(), isNot(contains('PRIVATE')));
    expect(repo.stored, log.read());
  });
  test('restore trim keeps recent complete lines within the character cap',
      () async {
    final repo = DelayedLogRepo()
      ..stored = List.filled(800, '[12:00:00] [ujing] U净登录成功\n').join();
    final log = DiagnosticLog(repo: repo);
    await log.ready;
    log.log('hotwater', '住理登录成功');
    await log.flush();
    expect(log.read().length, lessThanOrEqualTo(DiagnosticLog.maxChars));
    expect(log.read(), contains('U净登录成功'));
    expect(log.read(), contains('住理登录成功'));
    expect(log.read(), startsWith('['));
    expect(repo.stored, log.read());
  });
  test(
      'all sensitive shapes and truncation boundaries are filtered before storage',
      () async {
    final repo = DelayedLogRepo();
    final log = DiagnosticLog(repo: repo);
    await log.ready;
    for (final payload in [
      'mobile=13912345678',
      'phone=13912345678',
      'orderId=PRIVATE_ORDER deviceId=PRIVATE_DEVICE',
      '{"Cookie":"PRIVATE_COOKIE","Authorization":"PRIVATE_AUTH"}',
      'https://host.invalid/PRIVATE_PATH?sign=PRIVATE_SIGN&token=PRIVATE_TOKEN',
      'password: PRIVATE_PASS\nsmsCode=PRIVATE_SMS',
      'bleKey=PRIVATE_BLE payment=PRIVATE_PAYMENT',
      '住理接口失败 endpoint=PRIVATE_ENDPOINT code=PRIVATE_CODE',
      '热水操作失败 type=PRIVATE_TYPE',
      '支付宝返回 resultStatus=PRIVATE_PAY',
      '${List.filled(17000, 'x').join()}PRIVATE_TAIL',
    ]) {
      log.log('auth', payload);
    }
    log.log('PRIVATE_TAG', 'U净登录成功');
    await log.flush();
    expect(log.read(), isNot(contains('PRIVATE')));
    expect(log.read(), isNot(contains('13912345678')));
    expect(repo.stored, log.read());
    final restarted = DiagnosticLog(repo: repo);
    await restarted.ready;
    expect(restarted.read(), log.read());
  });
  test('known operation stage and failure category remain useful', () async {
    final log = DiagnosticLog(repo: InMemoryDiagnosticLogRepository());
    log.log('hotwater', '热水启动阶段=handshake_confirm');
    log.log('hotwater',
        '住理接口失败 endpoint=consume/list_record_by_staffid code=error_args');
    log.log('hotwater', '热水操作失败 type=TimeoutException');
    await log.flush();
    expect(log.read(), contains('handshake_confirm'));
    expect(log.read(), contains('code=error_args'));
    expect(log.read(), contains('TimeoutException'));
  });
}
