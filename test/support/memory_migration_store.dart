import 'package:flandresy/src/data/legacy_data_migration.dart';

class MemoryMigrationStore implements LegacyMigrationStore {
  MemoryMigrationStore([Map<String, Object>? legacy]) : legacy = legacy ?? {};
  final Map<String, Object> legacy;
  final Map<String, String> values = {};
  String? failKey;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failKey == key) throw StateError('injected write failure');
    values[key] = value;
  }

  @override
  Future<Map<String, Object>> readLegacyValues() async => Map.of(legacy);
}
