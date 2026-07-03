// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used indirectly through app rendering; this config loads the project font for golden tests
// and provides an in-memory SharedPreferences backend (P1) so the default SharedPrefs-backed
// SettingsRepository works under flutter test without a platform channel.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Empty initial values → deterministic default (zhuli); existing goldens unchanged.
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await loadAppFonts();
  await testMain();
}

