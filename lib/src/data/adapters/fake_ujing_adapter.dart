// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Fake Ujing adapter (no visual constants). Moves the fake data + timing that previously lived
// inline in water/washer/account actions here, 1:1 (delays/values/text preserved) — so the
// refactor is zero-behavior-change. Real values come from legacy 抓包 (133ml/2s/¥0.02, 海七套餐).

import 'dart:async';

import '../../runtime/models/account_session.dart';
import '../../runtime/models/washer_order.dart';
import '../../runtime/models/water_order.dart' hide formatFenAmount;
import 'ujing_adapter.dart';

/// Fake 实现：保留原有 fake 时序/数值/文案。网络延迟由本类承载（对齐真实 adapter 的 IO 延迟）。
class FakeUjingAdapter implements IUjingAdapter {
  const FakeUjingAdapter();

  static const Duration _netDelay = Duration(milliseconds: 620);
  static const Duration _payDelay = Duration(milliseconds: 800);

  @override
  Future<void> requestCaptcha(String mobile) async {
    await Future<void>.delayed(_netDelay);
  }

  @override
  Future<UjingAccountUi> login(String mobile, String captcha) async {
    await Future<void>.delayed(_netDelay);
    // fake 派生账号字段（真实由接口返回）；末 4 位派生 userId，服务主体固定。
    return UjingAccountUi(
      mobile: mobile,
      userId:
          'U${mobile.length >= 4 ? mobile.substring(mobile.length - 4) : mobile}',
      serviceSubjectId: 'haiqi-7',
    );
  }

  @override
  Future<WaterPrepareResult> scanAndCreateWaterOrder(String cd) async {
    await Future<void>.delayed(_netDelay);
    // ready：抓包真值（马房山校区，10 元小票余额 1000 分）。
    final ready = WaterReadyUi(
      cd: cd.isEmpty ? '0011202108055265' : cd,
      serviceSubjectId: '37810',
      serviceSubjectName: '武汉理工大学.马房山校区',
      storeId: '63199627046cb84fd7c9f7ba',
      balanceFen: 1000,
    );
    if (ready.balanceFen <= 0) {
      return WaterPrepareResult(ready: ready, order: null);
    }
    final order = WaterOrderUi(
      orderId: '1102876060',
      orderNo: 'WO-${ready.cd}',
      serviceSubjectName: ready.serviceSubjectName,
      storeName: '学海7舍-5',
      deviceNo: '070501',
      orderStatus: '0',
      orderStatusName: '订单创建',
      statusRemark: '订单创建',
      warmWaterMl: 0,
      waterSeconds: 0,
      payment: 0,
    );
    return WaterPrepareResult(ready: ready, order: order);
  }

  @override
  Future<WaterOrderUi> refreshWaterOrder(WaterOrderUi current) async {
    await Future<void>.delayed(_netDelay);
    // 完成：机器已接水并停止，上报最终用量与扣费（抓包真值 133ml/2s/¥0.02）。
    return WaterOrderUi(
      orderId: current.orderId,
      orderNo: current.orderNo,
      serviceSubjectName: current.serviceSubjectName,
      storeName: current.storeName,
      deviceNo: current.deviceNo,
      orderStatus: '50',
      orderStatusName: '取水正常完成',
      statusRemark: '取水正常完成',
      warmWaterMl: 133,
      waterSeconds: 2,
      payment: 0.02,
      payFlag: 1,
    );
  }

  @override
  Future<WasherProgramUi> scanWasher(String qrCode) async {
    await Future<void>.delayed(_netDelay);
    return _fakeProgram(qrCode);
  }

  @override
  Future<WasherOrderUi> createWasherOrder({
    required WasherProgramUi program,
    required int washModelId,
    required int temperatureId,
    int? detergentGearId,
    int? disinfectantGearId,
    required int orderSeq,
  }) async {
    await Future<void>.delayed(_netDelay);
    final model = program.models.firstWhere(
      (m) => m.id == washModelId,
      orElse: () => program.models.first,
    );
    final detergent = _findAddition(model, 'wp_detergentGearId', detergentGearId);
    final disinfect =
        _findAddition(model, 'wp_disinfectantGearId', disinfectantGearId);
    // 水温档价纳入 fake payPrice（同 UI _totalFen 共用 kWasherTemperaturePriceFen）→
    // fake 下单金额 == UI 预估，否则模拟模式支付卡金额与预估不一致。
    final tempFen = kWasherTemperaturePriceFen[temperatureId] ?? 0;
    final totalFen = model.priceFen +
        tempFen +
        (detergent?.priceFen ?? 0) +
        (disinfect?.priceFen ?? 0);
    return WasherOrderUi(
      orderId: '11028${76060 + orderSeq}',
      deviceNo: program.deviceNo,
      statusText: '待支付',
      payPrice: formatFenAmount(totalFen),
      status: '10',
    );
  }

  @override
  Future<WasherOrderUi> payWasherOrder(WasherOrderUi order) async {
    await Future<void>.delayed(_payDelay);
    return order.copyWith(status: '20', statusText: '已预约');
  }

  @override
  Future<WasherOrderUi> startWasherOrder(
    WasherOrderUi order,
    int remainSeconds,
  ) async {
    await Future<void>.delayed(_netDelay);
    return order.copyWith(
      status: '40',
      statusText: '运行中',
      remainTimeSeconds: remainSeconds,
    );
  }

  @override
  Future<WasherOrderUi> stopWasherOrder(WasherOrderUi order) async {
    await Future<void>.delayed(_netDelay);
    return order.copyWith(status: '50', statusText: '已结束');
  }

  @override
  Future<void> cancelWasherOrder(WasherOrderUi order) async {
    // 本地 no-op（对齐 legacy fake cancelCurrentOrder = Unit）；仅承载 IO 延迟。
    await Future<void>.delayed(_netDelay);
  }

  @override
  Future<WasherOrderUi> refreshWasherOrder(WasherOrderUi order) async {
    await Future<void>.delayed(_netDelay);
    if (order.status == '40') {
      return order.copyWith(status: '50', statusText: '已完成');
    }
    return order;
  }

  WasherAdditionOptionUi? _findAddition(
    WasherModelUi model,
    String groupKey,
    int? gearId,
  ) {
    if (gearId == null) {
      return null;
    }
    for (final group in model.additionGroups) {
      if (group.key == groupKey) {
        for (final option in group.options) {
          if (option.id == gearId) {
            return option;
          }
        }
      }
    }
    return null;
  }

  WasherProgramUi _fakeProgram(String qrCode) {
    const detergentGroup = WasherAdditionGroupUi(
      key: 'wp_detergentGearId',
      name: '洗衣液',
      options: [
        WasherAdditionOptionUi(id: 1, name: '标准', priceFen: 100),
        WasherAdditionOptionUi(id: 2, name: '加量', priceFen: 200),
      ],
    );
    const disinfectGroup = WasherAdditionGroupUi(
      key: 'wp_disinfectantGearId',
      name: '除菌液',
      options: [
        WasherAdditionOptionUi(id: 1, name: '标准', priceFen: 150),
        WasherAdditionOptionUi(id: 2, name: '加量', priceFen: 250),
      ],
    );
    return const WasherProgramUi(
      deviceId: 'HQ7-WASH-01',
      deviceNo: 'W1006445',
      deviceTypeName: '海七洗衣机',
      storeName: '海七宿舍',
      status: '可下单',
      reason: '',
      createOrderEnabled: true,
      defaultWashModelId: 1,
      models: [
        WasherModelUi(
          id: 1,
          name: '超强洗',
          priceFen: 600,
          timeMinutes: 45,
          additionGroups: [detergentGroup, disinfectGroup],
        ),
        WasherModelUi(
          id: 2,
          name: '标准洗',
          priceFen: 450,
          timeMinutes: 35,
          additionGroups: [detergentGroup, disinfectGroup],
        ),
        WasherModelUi(id: 3, name: '快洗', priceFen: 300, timeMinutes: 20),
        WasherModelUi(id: 4, name: '单脱水', priceFen: 200, timeMinutes: 10),
      ],
    );
  }
}
