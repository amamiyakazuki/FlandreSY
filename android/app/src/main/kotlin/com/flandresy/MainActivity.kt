package com.flandresy

import android.os.Handler
import android.os.Looper
import com.alipay.sdk.app.PayTask
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "ujing/alipay"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "payV2") {
                val orderInfo = call.argument<String>("orderInfo")
                if (orderInfo.isNullOrEmpty()) {
                    result.error("INVALID_ORDER", "orderInfo is empty", null)
                    return@setMethodCallHandler
                }

                // PayTask.payV2 must be called off the main thread.
                // The SDK will present its own UI for payment.
                Thread {
                    try {
                        val payTask = PayTask(this@MainActivity)
                        // true = show loading / wait for result
                        val payResult: Map<String, String> = payTask.payV2(orderInfo, true)
                        // Return the full map so Dart can read "resultStatus"
                        Handler(Looper.getMainLooper()).post {
                            result.success(payResult)
                        }
                    } catch (e: Exception) {
                        Handler(Looper.getMainLooper()).post {
                            result.error("PAY_ERROR", e.message ?: "Unknown Alipay error", null)
                        }
                    }
                }.start()
            } else {
                result.notImplemented()
            }
        }
    }
}
