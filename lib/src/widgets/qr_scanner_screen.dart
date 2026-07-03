// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Design tokens used: AppColors.background/deepText/primary/onPrimary/surface, AppTypography.textTheme,
// AppCustomTokens spacing/radius.
//
// Thin camera layer over mobile_scanner (RSCAN). This is the ONLY widget that touches the real camera
// platform channel, and it is NOT verified by Codex (Linux, no camera/emulator) — real scanning is
// verified ON-DEVICE by the user. Tests/goldens NEVER pump this screen; the pure classifyScanRouting +
// runtime dispatch are fixture-tested instead. On first successful decode it pops the raw QR string;
// the caller (shui_shell) classifies + routes. Cancel pops null.
//
// 相机启动稳健性（真机「相机启动失败，请重试」修复）：
//   - mobile_scanner 7.x（升级自 5.2.3，消 KGP 弃用警告 + 相机稳定性改进）。
//   - autoStart:false + 自己显式 start()，避免 widget/生命周期重复 start 触发 genericError。
//   - 真正的「重试」按钮（原文案说重试却无入口）。
//   - app 生命周期：切后台 stop、回前台重启，避免相机会话残留。
//   - 错误 UI 显示真实错误码 + 详情（原兜底文案掩盖了具体原因，无法定位）。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../design_tokens.dart';

/// 全屏扫码页：识别到首个二维码即 `Navigator.pop(context, rawValue)`；取消返回 null。
/// 调用方（shui_shell）拿到字符串后交给 classifyScanRouting + runtime 分发。
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  // autoStart:false → 由本 State 显式控制 start()，避免与 widget 自动启动/生命周期
  // 重复调用 start() 撞车（mobile_scanner 5.x 「already started」→ genericError）。
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: false,
  );

  /// 防抖：识别成功只 pop 一次（onDetect 会连续回调）。
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_startScanner());
  }

  /// 显式启动相机；失败交给 MobileScanner 的 errorBuilder 呈现（含真实错误码）。
  /// 「重试」按钮也调用它。
  Future<void> _startScanner() async {
    try {
      await _controller.start();
    } catch (_) {
      // 启动异常由 errorBuilder 显示；此处吞掉避免未捕获异常。
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_startScanner());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(_controller.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(value.trim());
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepText,
      appBar: AppBar(
        backgroundColor: AppColors.deepText,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        title: Text(
          '扫码使用',
          style: AppTypography.textTheme.titleMedium?.copyWith(
            color: AppColors.onPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            // mobile_scanner 7.x：errorBuilder 去掉了第三个 child 参数。
            errorBuilder: (context, error) => _ScannerError(
              error: error,
              onRetry: _startScanner,
            ),
          ),
          // 取景提示框（纯装饰）。
          Center(
            child: Container(
              width: AppCustomTokens.scanPanelHeight * 2,
              height: AppCustomTokens.scanPanelHeight * 2,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.onPrimary,
                  width: AppCustomTokens.strokeThin,
                ),
                borderRadius: BorderRadius.circular(AppCustomTokens.radiusLarge),
              ),
            ),
          ),
          Positioned(
            left: AppCustomTokens.spaceLg,
            right: AppCustomTokens.spaceLg,
            bottom: AppCustomTokens.spaceXl,
            child: Text(
              '将饮水机或洗衣机二维码对准取景框',
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: AppColors.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 相机权限/初始化失败提示（真机由用户授权后重试）。
/// 显示真实错误码 + 详情，并提供「重试」按钮（对齐文案，可从瞬时失败恢复）。
class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error, required this.onRetry});

  final MobileScannerException error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final bool permissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => '相机权限被拒绝，请在系统设置中开启后重试',
      MobileScannerErrorCode.unsupported => '当前设备不支持相机扫码',
      _ => '相机启动失败，请重试',
    };
    // 真实错误码 + 原生详情，方便真机定位（原兜底文案掩盖了具体原因）。
    final detail = error.errorDetails?.message;
    final diagnostic = detail == null || detail.isEmpty
        ? error.errorCode.name
        : '${error.errorCode.name}：$detail';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppCustomTokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: AppColors.onPrimary,
              ),
            ),
            const SizedBox(height: AppCustomTokens.spaceSm),
            Text(
              diagnostic,
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.bodySmall?.copyWith(
                color: AppColors.onPrimary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppCustomTokens.spaceLg),
            // 权限被拒时「重试」无用（需去系统设置），故仅在非权限错误时给重试按钮。
            if (!permissionDenied)
              OutlinedButton(
                onPressed: () => onRetry(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onPrimary,
                  side: const BorderSide(color: AppColors.onPrimary),
                ),
                child: const Text('重试'),
              ),
          ],
        ),
      ),
    );
  }
}
