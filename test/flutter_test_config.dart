// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Phase 3：golden 检测已整体移除（视觉反复迭代期不再维护 golden 基线，改真机 + widget 断言）。
// 本 config 仅保留全测试共用的 in-memory SharedPreferences 后端（P1），使默认
// SharedPrefs 支撑的 SettingsRepository 在 flutter test 下无需平台通道即可工作。

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 空初始值 → 确定性默认（zhuli）。
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await testMain();
}
