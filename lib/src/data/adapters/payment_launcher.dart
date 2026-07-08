// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Payment SDK seam (no visual constants). Splits "the Alipay SDK jump" (PayTask.payV2 — native,
// real money, verified ON-DEVICE by the user) from the payment HTTP layer (payment/methods +
// payment/arguments → orderInfo, testable via fixtures). UjingHttpAdapter depends on this interface;
// tests + main line inject FakePaymentLauncher; real-device verification injects RealPaymentLauncher.

/// 支付 SDK 调用 seam：拿到支付宝 `orderInfo` 后，负责拉起 SDK 并返回结果码。
///
/// 约定：
/// - 返回支付宝 `resultStatus`（如 '9000' 成功、'6001' 取消、'8000' 处理中）。
/// - 实现方**只**负责「拉起 SDK 那一跳」，不碰 HTTP / runtime state；
///   订单详情刷新由 adapter 在 launcher 返回后自行拉 `orders/{id}/detail`。
abstract class PaymentLauncher {
  /// 用支付宝 SDK 支付给定 orderInfo，返回 resultStatus。
  Future<String> payWithAlipay(String orderInfo);
}

/// Fake 实现：不接触真实 SDK，直接返回成功码 '9000'。
/// 默认注入（主线 + 测试），保持 A2 前的 fake「支付成功」行为一致。
class FakePaymentLauncher implements PaymentLauncher {
  const FakePaymentLauncher();

  /// 支付宝成功码（对齐 legacy `"9000".equals(resultStatus)` 判定）。
  static const String kAlipaySuccess = '9000';

  @override
  Future<String> payWithAlipay(String orderInfo) async => kAlipaySuccess;
}
