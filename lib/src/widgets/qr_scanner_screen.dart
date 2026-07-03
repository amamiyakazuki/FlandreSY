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

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// 防抖：识别成功只 pop 一次（onDetect 会连续回调）。
  bool _handled = false;

  @override
  void dispose() {
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
            errorBuilder: (context, error, child) => _ScannerError(error: error),
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
class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => '相机权限被拒绝，请在系统设置中开启后重试',
      MobileScannerErrorCode.unsupported => '当前设备不支持相机扫码',
      _ => '相机启动失败，请重试',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppCustomTokens.spaceLg),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.textTheme.bodyMedium?.copyWith(
            color: AppColors.onPrimary,
          ),
        ),
      ),
    );
  }
}
