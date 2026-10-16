// Payment SDK seam (no visual constants). Splits "the Alipay SDK jump" (PayTask.payV2 — native,
// real money, verified ON-DEVICE by the user) from the payment HTTP layer (payment/methods +
// payment/arguments → orderInfo, testable via fixtures). UjingHttpAdapter depends on this interface;
// Production explicitly injects RealPaymentLauncher; tests supply their own launcher.

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
