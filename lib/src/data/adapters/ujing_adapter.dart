// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Ujing adapter interface (no visual constants). Separates data source (what the Ujing backend
// returns) from state management (emit/notify in the runtime mixins). Fake + real HTTP both
// implement this. Method shapes align with legacy UjingRuntimeAdapter.

import '../../runtime/models/account_session.dart';
import '../../runtime/models/washer_order.dart';
import '../../runtime/models/water_order.dart';

/// Ujing 后端错误。actions 捕获后 emit failure。
/// [authInvalid] = 服务端明确拒绝了当前凭证（401/403 等），非「从未登录」也非网络抖动 →
/// action 层据此清 secure + adapter 内存 token + 账号 state 并置 loginRequired（RELOG）。
class UjingException implements Exception {
  const UjingException(this.message, {this.code, this.authInvalid = false});

  final String message;
  final String? code;
  final bool authInvalid;

  @override
  String toString() => 'UjingException($code): $message';
}

/// 饮水扫码准备结果（一次调用返回 ready + 初始订单，对齐 legacy 一步式）。
class WaterPrepareResult {
  const WaterPrepareResult({required this.ready, required this.order});

  final WaterReadyUi ready;

  /// 初始接水订单（status='0'）。余额充足时非空；余额不足时为 null。
  final WaterOrderUi? order;
}

/// Ujing 后端适配器接口（P4 A1）。
///
/// 约定：实现方**只**负责「拿数据」（含真实的网络/时序延迟），返回现有 UI 模型；
/// 不碰 runtime state、不 emit。校验/编排/持久化/历史累积由 runtime action 负责。
abstract class IUjingAdapter {
  // ===== U净账号 =====
  /// 请求验证码（fake：延时后视为已发送）。
  Future<void> requestCaptcha(String mobile);

  /// 登录 U净，返回账号信息。
  Future<UjingAccountUi> login(String mobile, String captcha);

  // ===== 饮水 =====
  /// 扫码识别饮水机 + 准备 ready + 创建初始接水订单（一次延迟，对齐 legacy）。
  Future<WaterPrepareResult> scanAndCreateWaterOrder(String cd);

  /// 刷新接水订单（fake：视为机器已完成，返回终态订单）。
  Future<WaterOrderUi> refreshWaterOrder(WaterOrderUi current);

  // ===== 洗衣 =====
  /// 扫码识别洗衣机，返回下单 program。
  Future<WasherProgramUi> scanWasher(String qrCode);

  /// 创建洗衣订单（status='10' 待支付）。orderSeq 由调用方维护（保证订单号稳定）。
  Future<WasherOrderUi> createWasherOrder({
    required WasherProgramUi program,
    required int washModelId,
    required int temperatureId,
    int? detergentGearId,
    int? disinfectantGearId,
    required int orderSeq,
  });

  /// 支付宝支付（fake 成功 → status='20' 已预约）。
  Future<WasherOrderUi> payWasherOrder(WasherOrderUi order);

  /// 启动洗衣机（status → '40' 运行；remainSeconds 由调用方按套餐时长给定）。
  Future<WasherOrderUi> startWasherOrder(WasherOrderUi order, int remainSeconds);

  /// 提前停止（status → '50' 已结束）。
  Future<WasherOrderUi> stopWasherOrder(WasherOrderUi order);

  /// 取消订单（真实：POST orders/{orderId}/cancel 作废服务端订单；fake：本地 no-op）。
  /// 对齐 legacy UjingApi.cancelOrder。成功后由 action 层清本地订单 + 历史标「已取消」。
  Future<void> cancelWasherOrder(WasherOrderUi order);

  /// 刷新洗衣订单（运行中 → '50' 完成；否则原样返回）。
  Future<WasherOrderUi> refreshWasherOrder(WasherOrderUi order);
}
