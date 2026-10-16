import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flandresy/src/data/legacy_data_migration.dart';
import 'support/memory_migration_store.dart';

void main() {
  for (final preference in [null, false, true]) {
    test(
        'old data requires login even when simulation preference is $preference',
        () async {
      final store = MemoryMigrationStore({
        'ujing_mobile': 'old',
        if (preference != null) 'use_simulated_backend': preference
      });
      final migration = LegacyDataMigration(store);
      await migration.prepare();
      expect(migration.ready, isTrue);
      for (final service in ['ujing', 'zhuli', 'shower798']) {
        expect(migration.needsLogin(service), isTrue);
      }
      expect(jsonDecode(store.values[LegacyDataMigration.backupKey]!)['values'],
          store.legacy);
      await migration.confirmLogin('ujing');
      final restarted = LegacyDataMigration(store);
      await restarted.prepare();
      expect(restarted.needsLogin('ujing'), isFalse);
      expect(restarted.needsLogin('zhuli'), isTrue);
    });
  }
  test(
      'new install has no migration prompt; later data is not treated as legacy',
      () async {
    final store = MemoryMigrationStore();
    final migration = LegacyDataMigration(store);
    await migration.prepare();
    expect(migration.hasLegacy, isFalse);
    store.legacy['ujing_mobile'] = 'new';
    final restarted = LegacyDataMigration(store);
    await restarted.prepare();
    expect(restarted.needsLogin('ujing'), isFalse);
  });
  for (final key in [
    LegacyDataMigration.backupKey,
    LegacyDataMigration.journalKey
  ]) {
    test(
        'interruption at $key blocks and retries without replacing original backup',
        () async {
      final store = MemoryMigrationStore({'ujing_mobile': 'old'})
        ..failKey = key;
      final migration = LegacyDataMigration(store);
      await migration.prepare();
      expect(migration.blocked, isTrue);
      expect(migration.needsLogin('ujing'), isTrue);
      final original = store.values[LegacyDataMigration.backupKey];
      store.failKey = null;
      await migration.prepare();
      expect(migration.ready, isTrue);
      if (original != null) {
        expect(store.values[LegacyDataMigration.backupKey], original);
      }
      expect(store.legacy['ujing_mobile'], 'old');
    });
  }
  for (final raw in ['{broken', 42]) {
    test('bad stored data ($raw) preserves exact value and fails closed',
        () async {
      final store = MemoryMigrationStore({'hotwater_session': raw});
      final migration = LegacyDataMigration(store);
      await migration.prepare();
      expect(migration.blocked, isTrue);
      expect(store.values.containsKey(LegacyDataMigration.journalKey), isFalse);
      expect(
          jsonDecode(store.values[LegacyDataMigration.backupKey]!)['values']
              ['hotwater_session'],
          raw);
    });
  }
  test(
      'concurrent service confirmations do not lose writes; failed save keeps gate',
      () async {
    final store = MemoryMigrationStore({'ujing_mobile': 'old'});
    final migration = LegacyDataMigration(store);
    await migration.prepare();
    await Future.wait(
        [migration.confirmLogin('ujing'), migration.confirmLogin('zhuli')]);
    expect(migration.needsLogin('ujing'), isFalse);
    expect(migration.needsLogin('zhuli'), isFalse);
    store.failKey = LegacyDataMigration.journalKey;
    await expectLater(migration.confirmLogin('shower798'), throwsStateError);
    expect(migration.needsLogin('shower798'), isTrue);
    store.failKey = null;
    await migration.prepare();
    expect(migration.needsLogin('shower798'), isTrue);
  });
}
