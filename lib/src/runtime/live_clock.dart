// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Injectable clock (no visual constants). Lets washer live countdown + Orders ticker use real
// time in production (SystemLiveClock) but a fixed value under tests (golden determinism).

/// 时间源抽象（W2 live 倒计时）。runtime + OrdersScreen 共用同一实例。
abstract class LiveClock {
  int nowMillis();
}

/// 生产实现：真实墙钟。
class SystemLiveClock implements LiveClock {
  const SystemLiveClock();

  @override
  int nowMillis() => DateTime.now().millisecondsSinceEpoch;
}

/// 测试实现：固定时间 → live 剩余恒定 → golden 可重现。
class FixedLiveClock implements LiveClock {
  const FixedLiveClock(this._fixed);

  final int _fixed;

  @override
  int nowMillis() => _fixed;
}

/// 毫秒时间戳 → 「HH:mm」本地时间（P1-FIX：取代设备刷新/接水完成的假「刚刚」）。
/// 注入 clock 的 nowMillis 走此格式；测试用 FixedLiveClock → 固定串保确定性。
String formatClockTime(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
