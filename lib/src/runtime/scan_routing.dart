// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Pure scan-QR classification (no visual constants, no IO). 1:1 port of legacy
// runtime/ShuiUiModels.kt `classifyScanRouting` + `ScanRouting`. The camera layer
// (qr_scanner_screen.dart, mobile_scanner) feeds a raw QR string here; this file decides
// which service flow to route to. Pure Dart → fully fixture-tested; the camera is verified
// ON-DEVICE by the user (not by Codex).

/// 扫码路由结果（对齐 legacy `ScanRouting` sealed class）。
sealed class ScanRouting {
  const ScanRouting();
}

/// 洗衣机二维码 → 走 scanWasher（qr 原样透传给 Ujing scanWasherCode）。
class ScanRoutingWasher extends ScanRouting {
  const ScanRoutingWasher();
}

/// 饮水机二维码 → 走 scanAndCreateWaterOrder（携带 cd 设备码）。
class ScanRoutingDrinkingWater extends ScanRouting {
  const ScanRoutingDrinkingWater(this.cd);

  final String cd;
}

/// 无法识别的二维码 → 提示 reason，不触发任何后端调用。
class ScanRoutingUnknown extends ScanRouting {
  const ScanRoutingUnknown(this.reason);

  final String reason;
}

/// 分类扫码结果（对齐 legacy `classifyScanRouting`）。
/// 顺序敏感：先判饮水（cd + q.ujing.com.cn/ed 或 type=drink/water），
/// 再判洗衣（u_download.html / type=ujing / uuid= / scanwashercode / ucqrc+cd），
/// 再兜底 q.ujing.com.cn/ed → 饮水（cd 可空），最后 unknown。
ScanRouting classifyScanRouting(String qrCode) {
  final raw = qrCode.trim();
  if (raw.isEmpty) {
    return const ScanRoutingUnknown('二维码为空');
  }
  final lower = raw.toLowerCase();

  final cd = _extractCd(raw);

  if (cd != null &&
      cd.isNotEmpty &&
      (lower.contains('q.ujing.com.cn/ed') ||
          lower.contains('/ed/') ||
          lower.contains('type=drink') ||
          lower.contains('type=water'))) {
    return ScanRoutingDrinkingWater(cd);
  }

  if (lower.contains('u_download.html') ||
      lower.contains('type=ujing') ||
      lower.contains('scanwashercode') ||
      lower.contains('uuid=') ||
      (cd != null && cd.isNotEmpty && lower.contains('q.ujing.com.cn/ucqrc'))) {
    return const ScanRoutingWasher();
  }

  if (lower.contains('q.ujing.com.cn/ed')) {
    return ScanRoutingDrinkingWater(cd ?? '');
  }

  return const ScanRoutingUnknown('暂时无法识别该二维码类型');
}

/// 取 query 参数 `cd`（对齐 legacy Uri.getQueryParameter + 正则兜底）。
/// 先按 URI 解析，失败或缺失时用正则从原串抽取。
String? _extractCd(String raw) {
  final uri = Uri.tryParse(raw);
  final fromUri = uri?.queryParameters['cd']?.trim();
  if (fromUri != null && fromUri.isNotEmpty) {
    return fromUri;
  }
  final match =
      RegExp(r'[?&]cd=([^&]+)', caseSensitive: false).firstMatch(raw);
  final captured = match?.group(1)?.trim();
  if (captured != null && captured.isNotEmpty) {
    return captured;
  }
  return null;
}
