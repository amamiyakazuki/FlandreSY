// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Real Alipay payment launcher. Invokes the native Alipay SDK jump (legacy:
// com.alipay.sdk.app.PayTask.payV2(orderInfo, true)) via MethodChannel 'ujing/alipay'.
// The Android native side is wired (MainActivity.kt payV2 handler + alipaysdk dependency +
// H5PayActivity from the SDK's own manifest). iOS native side is NOT yet wired.
// Real money / sandbox verification is done ON-DEVICE by the user. Injected in the default
// (real) mode; skipped only when the simulate-backend toggle is ON (or --dart-define=SIMULATE_BACKEND=true).

import 'package:flutter/services.dart';

import 'payment_launcher.dart';
import 'ujing_adapter.dart';

/// 真实支付宝 SDK launcher：经 platform channel `ujing/alipay` 调原生 `payV2`。
///
/// Android 原生端已接入（MainActivity.kt：PayTask(activity).payV2(orderInfo, true)
/// → 返回 result map，Dart 取 `resultStatus`）。iOS 原生端尚未接入 —— 在 iOS 上
/// 通道未注册会抛 [MissingPluginException]，本类映射为 [UjingException]，不伪装成功。
/// 真钱/沙箱验证由用户真机完成。
class RealPaymentLauncher implements PaymentLauncher {
  const RealPaymentLauncher();

  /// 与原生约定的方法通道名（原生端注册同名 channel + 'payV2' 方法）。
  static const MethodChannel channel = MethodChannel('ujing/alipay');

  @override
  Future<String> payWithAlipay(String orderInfo) async {
    try {
      // 原生返回 Map<String,String>（含 resultStatus/memo/result）。取 resultStatus。
      final result =
          await channel.invokeMapMethod<String, dynamic>('payV2', <String, Object?>{
        'orderInfo': orderInfo,
      });
      final status = result?['resultStatus'];
      return status == null ? '' : '$status';
    } on MissingPluginException {
      // 原生通道未注册（如 iOS 未接入）。诚实报错，不伪装成功。
      throw const UjingException('支付宝 SDK 未接入当前平台（需原生 PayTask，见文件注释步骤）');
    } on PlatformException catch (e) {
      // 原生 payV2 抛错（订单无效 / SDK 异常）。
      throw UjingException('支付宝支付失败：${e.message ?? e.code}', code: e.code);
    }
  }
}
