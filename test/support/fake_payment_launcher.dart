import 'package:flandresy/src/data/adapters/payment_launcher.dart';

/// Fake 实现：不接触真实 SDK，直接返回成功码 '9000'。
/// 默认注入（主线 + 测试），保持 A2 前的 fake「支付成功」行为一致。
class FakePaymentLauncher implements PaymentLauncher {
  const FakePaymentLauncher();

  /// 支付宝成功码（对齐 legacy `"9000".equals(resultStatus)` 判定）。
  static const String kAlipaySuccess = '9000';

  @override
  Future<String> payWithAlipay(String orderInfo) async => kAlipaySuccess;
}
