import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/method_channel_shared_preferences.dart';
import 'package:flandresy/src/data/shared_prefs_diagnostic_log_repository.dart';
import 'package:flandresy/src/runtime/diagnostic_log.dart';
import 'package:flandresy/src/more/log_screen.dart';
import 'diagnostic_log_test.dart' show DelayedLogRepo;

const safe = '[12:00:00] [ujing] U净登录成功\n';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('legacy diagnostics cleared once; accounts and backups untouched',
      () async {
    final business = {
      'ujing_mobile': 'account-private',
      'legacy_backup': 'retained'
    };
    SharedPreferences.setMockInitialValues(
        {...business, 'diagnostic_log': 'token=OLD_PRIVATE'});
    final repo = SharedPrefsDiagnosticLogRepository();
    expect(await repo.load(), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('diagnostic_log'), isNot(contains('OLD_PRIVATE')));
    for (final entry in business.entries) {
      expect(prefs.getString(entry.key), entry.value);
    }
    expect(prefs.getKeys(), {...business.keys, 'diagnostic_log'});
    await repo.save(safe);
    expect(await SharedPrefsDiagnosticLogRepository().load(), safe);
  });
  test('unexpected legacy value type clears only the diagnostic key', () async {
    SharedPreferences.setMockInitialValues(
        {'diagnostic_log': 12345, 'business': 'keep'});
    final repo = SharedPrefsDiagnosticLogRepository();
    expect(await repo.load(), isEmpty);
    expect(
        (await SharedPreferences.getInstance()).getString('business'), 'keep');
    expect(await repo.load(), isEmpty);
  });
  test('new-format restore and direct save filter untrusted content', () async {
    SharedPreferences.setMockInitialValues({
      'diagnostic_log': jsonEncode({
        'diagnosticSchema': 1,
        'text': '$safe[12:00:01] [auth] Cookie=PRIVATE_COOKIE\n',
      })
    });
    final repo = SharedPrefsDiagnosticLogRepository();
    expect(await repo.load(), startsWith(safe));
    expect((await SharedPreferences.getInstance()).getString('diagnostic_log'),
        isNot(contains('PRIVATE')));
    await repo.save('$safe[12:00:02] [auth] {"password":"PRIVATE_PASSWORD"}\n');
    expect(await repo.load(), isNot(contains('PRIVATE')));
  });
  for (final failure in ['false', 'throw']) {
    test('migration and save $failure reload cache and remain retryable',
        () async {
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance =
          MethodChannelSharedPreferencesStore();
      addTearDown(() => SharedPreferences.setMockInitialValues({}));
      final disk = <String, Object>{
        'flutter.diagnostic_log': 'OLD_PRIVATE',
        'flutter.account': 'keep'
      };
      var mode = failure;
      const channel = MethodChannel('plugins.flutter.io/shared_preferences');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getAll') return Map.of(disk);
        if (call.method == 'setString') {
          if (mode == 'false') return false;
          if (mode == 'throw') throw PlatformException(code: 'disk');
          final args = call.arguments as Map;
          disk[args['key'] as String] = args['value'] as Object;
          return true;
        }
        throw StateError('unexpected call');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final repo = SharedPrefsDiagnosticLogRepository();
      final log = DiagnosticLog(repo: repo);
      await log.ready;
      expect(log.read(), isEmpty);
      expect(log.storageError, isNotNull);
      expect(disk['flutter.diagnostic_log'], 'OLD_PRIVATE');
      expect(
          (await SharedPreferences.getInstance()).getString('diagnostic_log'),
          'OLD_PRIVATE');
      mode = 'ok';
      await log.retryStorage();
      expect(log.storageError, isNull);
      expect(disk['flutter.diagnostic_log'], isNot(contains('OLD_PRIVATE')));
      await repo.save(safe);
      final before = Map.of(disk);
      mode = failure;
      await expectLater(repo.save(''), throwsA(anything));
      expect(disk, before);
      expect(await repo.load(), safe);
      mode = 'ok';
      await repo.save('');
      expect(await repo.load(), isEmpty);
      expect(disk['flutter.account'], 'keep');
    });
  }

  testWidgets(
      'clear reports success only after save; failure retry and copy are safe',
      (tester) async {
    final repo = DelayedLogRepo();
    final log = DiagnosticLog(repo: repo);
    await log.ready;
    log.log('ujing', 'U净登录成功');
    log.log('auth', 'Authorization: PRIVATE_TOKEN');
    await log.flush();
    await tester
        .pumpWidget(MaterialApp(home: LogScreen(log: log, onBack: () {})));
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    expect(copied, contains('U净登录成功'));
    expect(copied, isNot(contains('PRIVATE')));
    final gate = Completer<void>();
    repo.saving = gate;
    repo.fail = true;
    await tester.tap(find.text('清空'));
    await tester.pump();
    expect(find.textContaining('正在清空日志'), findsOneWidget);
    expect(find.textContaining('日志已清空'), findsNothing);
    expect(log.read(), contains('U净登录成功'));
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('清空未完成'), findsOneWidget);
    expect(log.read(), contains('U净登录成功'));
    repo.fail = false;
    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();
    expect(find.textContaining('日志已清空'), findsOneWidget);
    expect(find.text('暂无日志'), findsOneWidget);
    expect(repo.stored, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('storage migration failure exposes retry without any raw text',
      (tester) async {
    final repo = DelayedLogRepo()..loading = Completer<String>();
    final log = DiagnosticLog(repo: repo);
    await tester
        .pumpWidget(MaterialApp(home: LogScreen(log: log, onBack: () {})));
    repo.loading!.completeError(StateError('PRIVATE'));
    await tester.pumpAndSettle();
    expect(find.text('重试存储'), findsOneWidget);
    expect(log.read(), isEmpty);
    repo.loading = null;
    await tester.tap(find.text('重试存储'));
    await tester.pumpAndSettle();
    expect(find.text('诊断存储已恢复'), findsOneWidget);
    expect(find.textContaining('PRIVATE'), findsNothing);
  });
  testWidgets('leaving during clear does not update a disposed screen',
      (tester) async {
    final repo = DelayedLogRepo();
    final log = DiagnosticLog(repo: repo);
    await log.ready;
    log.log('ujing', 'U净登录成功');
    await log.flush();
    await tester
        .pumpWidget(MaterialApp(home: LogScreen(log: log, onBack: () {})));
    final gate = Completer<void>();
    repo.saving = gate;
    await tester.tap(find.text('清空'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(log.read(), isEmpty);
  });
}
