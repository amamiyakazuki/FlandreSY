import Flutter
import UIKit
import AlipaySDK

/// iOS 13+ 场景生命周期。支付宝支付完成后经自定义 URL scheme（flandrepay）回跳，
/// 需在此把结果交回 AlipaySDK（payOrder 的 completionBlock 才会触发）。
/// Codex 无法在 Linux 编译/验证；iOS 真机 + 真钱由用户验。
class SceneDelegate: FlutterSceneDelegate {
  func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    for context in URLContexts {
      let url = context.url
      if url.host == "safepay" {
        // 从外部支付宝 App 回跳（standalone）。
        AlipaySDK.defaultService().processOrder(withPaymentResult: url) { _ in }
        // H5（钱包内 WebView）回跳。
        AlipaySDK.defaultService().processOrderWithPaymentResult(fromH5PayUrl: url) { _ in }
      }
    }
  }
}
