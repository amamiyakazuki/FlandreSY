// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Fake Zhuli hotwater adapter (no visual constants). Fake login/start/stop timing + text.
// P1-FIX: loadHistory now returns [] (the old hardcoded ¥1.20/¥2.40 rows leaked into real mode
// via PHIST persistence + a non-empty early-return that froze them). Real history is Zhuli-only.
// No real HTTP/BLE.

import 'dart:async';

import '../../runtime/models/hotwater_history.dart';
import 'hotwater_adapter.dart';

/// Fake 实现：保留原有 fake 时序/数值/文案。网络+BLE 延迟由本类承载（对齐真实 IO）。
class FakeHotwaterAdapter implements IHotwaterAdapter {
  const FakeHotwaterAdapter();

  static const Duration _netDelay = Duration(milliseconds: 620);
  static const Duration _historyDelay = Duration(milliseconds: 400);

  @override
  Future<ZhuliSessionData> loginZhuli(String phone, String password) async {
    await Future<void>.delayed(_netDelay);
    // fake session：真实由平台登录返回 serverAddr/secretKey 等；此处派生占位使 isValid。
    return ZhuliSessionData(
      platformToken: 'fake-token',
      userId: 'staff-$phone',
      identityCode: '',
      serverAddr: 'https://f5-zhuli.whxinna.com',
      serverAppId: '',
      serverId: '',
      secretKey: 'fake-secret',
    );
  }

  @override
  Future<HotwaterActionResult> startHotwater(String deviceId) async {
    await Future<void>.delayed(_netDelay);
    return HotwaterActionResult(
      deviceId: deviceId,
      statusText: '热水启动完成，供应中',
      orderId: 'HW-fake',
      isn: 'fake-isn',
    );
  }

  @override
  Future<HotwaterActionResult> stopHotwater(String deviceId) async {
    await Future<void>.delayed(_netDelay);
    return HotwaterActionResult(
      deviceId: deviceId,
      statusText: '热水已关闭',
    );
  }

  @override
  Future<List<HotwaterHistoryUi>> loadHistory() async {
    await Future<void>.delayed(_historyDelay);
    // P1-FIX：fake 不再造假历史（旧硬编码 ¥1.20/¥2.40 曾经 PHIST 落盘后在真实模式冻结消不掉）。
    // 真实历史只来自 RealZhuliAdapter.loadHistory（服务端）。模拟模式空历史 = 无演示单，符合预期。
    return const [];
  }
}
