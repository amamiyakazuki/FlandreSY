import 'package:flandresy/src/app/flandre_app.dart';
import 'package:flandresy/src/runtime/shui_runtime.dart';
import 'package:flandresy/src/data/legacy_data_migration.dart';
import 'package:flandresy/src/data/account_session_repository.dart';
import 'package:flandresy/src/data/history_repository.dart';
import 'package:flandresy/src/data/local_device_repository.dart';
import 'package:flandresy/src/data/secure_session_repository.dart';
import 'package:flandresy/src/data/settings_repository.dart';
import 'package:flandresy/src/data/water_order_repository.dart';
import 'package:flandresy/src/data/washer_history_repository.dart';
import 'package:flandresy/src/data/adapters/ujing_adapter.dart';
import 'package:flandresy/src/data/adapters/hotwater_adapter.dart';
import 'package:flandresy/src/data/adapters/shower798_adapter.dart';
import 'fake_ujing_adapter.dart';
import 'fake_hotwater_adapter.dart';
import 'fake_shower798_adapter.dart';
import 'memory_migration_store.dart';
export 'package:flandresy/src/runtime/shui_runtime.dart';

class TestRuntime extends ShuiRuntime {
  TestRuntime({
    SettingsRepository? settings,
    AccountSessionRepository? sessions,
    LocalDeviceRepository? devices,
    HistoryRepository? history,
    WaterOrderRepository? water,
    WasherHistoryRepository? washerHistory,
    SecureSessionRepository? secure,
    LegacyDataMigration? migration,
    IUjingAdapter? ujing,
    IHotwaterAdapter? hotwater,
    IShower798Adapter? shower798,
    super.clock,
    super.diagnosticLog,
    super.appVersion,
    super.initial,
  }) : super(
          settings: settings ?? InMemorySettingsRepository(),
          sessions: sessions ?? InMemoryAccountSessionRepository(),
          devices: devices ?? InMemoryLocalDeviceRepository(),
          history: history ?? InMemoryHistoryRepository(),
          water: water ?? InMemoryWaterOrderRepository(),
          washerHistory: washerHistory ?? InMemoryWasherHistoryRepository(),
          secure: secure ?? InMemorySecureSessionRepository(),
          migration: migration ?? LegacyDataMigration(MemoryMigrationStore()),
          ujing: ujing ?? const FakeUjingAdapter(),
          hotwater: hotwater ?? FakeHotwaterAdapter(),
          shower798: shower798 ?? FakeShower798Adapter(),
        );
}

class TestApp extends FlandreApp {
  TestApp({
    SettingsRepository? settings,
    AccountSessionRepository? sessions,
    LocalDeviceRepository? devices,
    HistoryRepository? history,
    WaterOrderRepository? water,
    WasherHistoryRepository? washerHistory,
    SecureSessionRepository? secure,
    LegacyDataMigration? migration,
    IUjingAdapter? ujing,
    IHotwaterAdapter? hotwater,
    IShower798Adapter? shower798,
    super.clock,
    super.diagnosticLog,
    super.appVersion,
    super.initial,
    super.key,
  }) : super(
          settings: settings ?? InMemorySettingsRepository(),
          sessions: sessions ?? InMemoryAccountSessionRepository(),
          devices: devices ?? InMemoryLocalDeviceRepository(),
          history: history ?? InMemoryHistoryRepository(),
          water: water ?? InMemoryWaterOrderRepository(),
          washerHistory: washerHistory ?? InMemoryWasherHistoryRepository(),
          secure: secure ?? InMemorySecureSessionRepository(),
          migration: migration ?? LegacyDataMigration(MemoryMigrationStore()),
          ujing: ujing ?? const FakeUjingAdapter(),
          hotwater: hotwater ?? FakeHotwaterAdapter(),
          shower798: shower798 ?? FakeShower798Adapter(),
        );
}

class TestRuntimeScope extends ShuiRuntimeScope {
  TestRuntimeScope({
    required super.child,
    SettingsRepository? settings,
    AccountSessionRepository? sessions,
    LocalDeviceRepository? devices,
    HistoryRepository? history,
    WaterOrderRepository? water,
    WasherHistoryRepository? washerHistory,
    SecureSessionRepository? secure,
    LegacyDataMigration? migration,
    IUjingAdapter? ujing,
    IHotwaterAdapter? hotwater,
    IShower798Adapter? shower798,
    super.clock,
    super.diagnosticLog,
    super.appVersion,
    super.initial,
    super.key,
  }) : super(
          settings: settings ?? InMemorySettingsRepository(),
          sessions: sessions ?? InMemoryAccountSessionRepository(),
          devices: devices ?? InMemoryLocalDeviceRepository(),
          history: history ?? InMemoryHistoryRepository(),
          water: water ?? InMemoryWaterOrderRepository(),
          washerHistory: washerHistory ?? InMemoryWasherHistoryRepository(),
          secure: secure ?? InMemorySecureSessionRepository(),
          migration: migration ?? LegacyDataMigration(MemoryMigrationStore()),
          ujing: ujing ?? const FakeUjingAdapter(),
          hotwater: hotwater ?? FakeHotwaterAdapter(),
          shower798: shower798 ?? FakeShower798Adapter(),
        );
}
