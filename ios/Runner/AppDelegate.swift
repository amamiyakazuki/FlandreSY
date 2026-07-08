import Flutter
import UIKit
// 支付宝 SDK（真机真实支付）。Codex 无法在 Linux 编译/验证，iOS 真机 + 真钱由用户验。
// 若模块名不同（use_frameworks! 静态链接时），可能需要 import AlipaySDK
import AlipaySDK

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// 与 Dart RealPaymentLauncher 约定的通道名（Android 同名）。
  private let alipayChannelName = "ujing/alipay"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // 注册支付宝支付通道（对齐 Android MainActivity 的 'ujing/alipay' payV2）。
    let messenger = engineBridge.pluginRegistry.registrar(forPlugin: "UjingAlipay")!.messenger()
    let channel = FlutterMethodChannel(name: alipayChannelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "payV2" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let args = call.arguments as? [String: Any],
        let orderInfo = args["orderInfo"] as? String,
        !orderInfo.isEmpty
      else {
        result(FlutterError(code: "INVALID_ORDER", message: "orderInfo is empty", details: nil))
        return
      }
      // AlipaySDK 回调在主线程；返回 resultDic 含 resultStatus。fromScheme 见 Info.plist LSApplicationQueriesSchemes / URL Types。
      AlipaySDK.defaultService().payOrder(orderInfo, fromScheme: "flandrepay") { resultDic in
        guard let dic = resultDic else {
          result(["resultStatus": ""])
          return
        }
        // 键为 NSNumber/String，统一转成 String（Dart 端读 resultStatus）。
        var out: [String: String] = [:]
        for (k, v) in dic {
          out["\(k)"] = "\(v)"
        }
        result(out)
      }
    }
  }
}
