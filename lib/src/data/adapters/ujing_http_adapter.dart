// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Real Ujing HTTP adapter (no visual constants). Real HTTP (through an injectable UjingTransport)
// for: login, drinking-water full chain, washer scan + create (A2), and washer pay + start + stop (A3).
// Request-building / JSON-parsing / error-mapping / payment orchestration are testable via fixtures
// (ujing_http_adapter_test + ujing_payment_test); the real socket lives in IoUjingTransport and the
// Alipay SDK jump lives behind PaymentLauncher — both verified ON-DEVICE by the user (not by Codex).
// WeChat / H5 / bill top-up are out of scope (Alipay only, like legacy's stable path).
// Endpoints/headers/parse shapes align with legacy UjingApi.java + UjingRuntimeAdapter.java +
// docs/ujing-water-flow.md + docs/service-interfaces.md. NOT enabled by default (main line = Fake).

import '../../runtime/models/account_session.dart';
import '../../runtime/models/washer_order.dart';
import '../../runtime/models/water_order.dart';
import 'io_ujing_transport.dart';
import 'payment_launcher.dart';
import 'ujing_adapter.dart';
import 'ujing_transport.dart';

/// 真实 Ujing HTTP 适配器（P4 A2）。有状态：持内存 token + 已扫套餐缓存
/// （对齐 legacy `UjingRuntimeAdapter` 的 currentProgram）。默认用 [IoUjingTransport]，
/// 测试注入伪 transport 回放抓包 JSON。token 仅内存，重启需重登录（持久化后续）。
class UjingHttpAdapter implements IUjingAdapter {
  UjingHttpAdapter({
    UjingTransport? transport,
    PaymentLauncher? launcher,
    String? token,
  })  : _transport = transport ?? IoUjingTransport(),
        _launcher = launcher ?? const FakePaymentLauncher(),
        _token = token;

  final UjingTransport _transport;

  /// 支付 SDK seam（A3）。默认 Fake（返回 9000）；真机注入 RealPaymentLauncher。
  final PaymentLauncher _launcher;

  /// 登录 token（对齐 legacy UjingSession.token）。需登录接口带 Bearer。
  /// PTOK：构造可注入已持久化 token（重启免重登）；登录成功后由 action 层读 [lastToken] 落盘。
  String? _token;

  /// PTOK：当前 token（供 action 层登录成功后持久化；未登录为 null）。
  String? get lastToken => _token;

  /// RELOG：服务端拒绝当前 token 时由 action 层调用，清内存凭证（配合 secure.clear + 账号 state 清空）。
  void invalidateAuth() {
    _token = null;
  }

  /// 已扫洗衣机套餐缓存（keyed by deviceId）：下单需 storeId/deviceTypeId,
  /// 而共享 UI 模型 [WasherProgramUi] 不含它们 → 缓存在 adapter 内部避免改模型。
  final Map<String, _ScannedProgram> _programs = <String, _ScannedProgram>{};

  String _requireToken() {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw const UjingException('请先登录 U净账号');
    }
    return token;
  }

  // ===== U净账号 =====

  @override
  Future<void> requestCaptcha(String mobile) async {
    // 对齐 legacy UjingApi.requestCaptcha：GET captcha，AFS 关闭参数，appCode=ZA。
    await _transport.send(UjingRequest(
      method: 'GET',
      path: 'captcha',
      appCode: 'ZA',
      query: <String, Object?>{
        'mobile': mobile,
        'type': 1,
        'sessionId': 'AFS_SWITCH_OFF',
        'token': 'AFS_SWITCH_OFF',
        'sig': 'AFS_SWITCH_OFF',
      },
    ));
  }

  @override
  Future<UjingAccountUi> login(String mobile, String captcha) async {
    // 对齐 legacy UjingApi.login：POST login {mobile, captcha}，data 取 token/userId/serviceSubjectId。
    final data = await _transport.send(UjingRequest(
      method: 'POST',
      path: 'login',
      appCode: 'ZA',
      body: <String, Object?>{'mobile': mobile, 'captcha': captcha},
    ));
    final token = _str(data, 'token');
    if (token.isEmpty) {
      throw const UjingException('U净登录成功但没有返回 token');
    }
    _token = token;
    return UjingAccountUi(
      mobile: _str(data, 'mobile', fallback: mobile),
      userId: _str(data, 'userId'),
      serviceSubjectId: _str(data, 'serviceSubjectId'),
    );
  }

  // ===== 饮水 =====

  @override
  Future<WaterPrepareResult> scanAndCreateWaterOrder(String cd) async {
    final token = _requireToken();
    final code = _extractWaterCd(cd);
    if (code.isEmpty) {
      throw const UjingException('没有识别到饮水设备码');
    }

    // 若传入的是完整二维码 URL，先 home/scanCode 确认属于饮水服务（对齐 legacy prepareWater）。
    if (cd.contains('://')) {
      final scan = await _transport.send(UjingRequest(
        method: 'POST',
        path: 'home/scanCode',
        appCode: 'ZA',
        authToken: token,
        body: <String, Object?>{'qrCode': cd.trim()},
      ));
      final service = _str(scan, 'service');
      if (service.isNotEmpty && service.toLowerCase() != 'water') {
        throw UjingException('该二维码不是饮水码：$service');
      }
    }

    // 确认校区/店铺 + 余额（changeWithScan → currentInfo，对齐 legacy）。
    final subject = await _transport.send(UjingRequest(
      method: 'POST',
      path: 'water/serviceSubject/changeWithScan',
      appCode: 'CA',
      weex: '1.0.102',
      authToken: token,
      body: <String, Object?>{'cd': code},
    ));
    final current = await _transport.send(UjingRequest(
      method: 'GET',
      path: 'app/water/serviceSubject/currentInfo',
      appCode: 'CA',
      weex: '1.0.102',
      authToken: token,
    ));

    final balanceFen = _int(current, 'balance', fallback: _int(subject, 'balance'));
    final ready = WaterReadyUi(
      cd: code,
      serviceSubjectId: _strAny(
        subject,
        const ['newServiceSubjectId', 'serviceSubjectId'],
      ),
      serviceSubjectName: _strAny(subject, const [
        'newServiceSubjectName',
        'serviceSubjectName',
        'ServiceSubjectName',
      ]),
      storeId: _str(subject, 'storeId'),
      balanceFen: balanceFen,
      giftBalanceFen: _int(current, 'giftBalance', fallback: _int(subject, 'giftBalance')),
    );

    // 余额不足：不创建订单，交给 action emit「请充值」（对齐 legacy balance<=0 抛错前置）。
    if (balanceFen <= 0) {
      return WaterPrepareResult(ready: ready, order: null);
    }

    // 创建接水订单（deviceId=cd）→ 拉一次详情得完整初始订单（status '0'）。
    final created = await _transport.send(UjingRequest(
      method: 'POST',
      path: 'water/createWaterOrder',
      appCode: 'CA',
      weex: '1.0.102',
      authToken: token,
      body: <String, Object?>{'deviceId': code},
    ));
    final orderId = _str(created, 'orderId');
    if (orderId.isEmpty || orderId == '0') {
      throw const UjingException('创建饮水订单成功但没有 orderId');
    }
    final order = await _fetchWaterOrderDetail(orderId, token);
    return WaterPrepareResult(ready: ready, order: order);
  }

  @override
  Future<WaterOrderUi> refreshWaterOrder(WaterOrderUi current) async {
    final token = _requireToken();
    return _fetchWaterOrderDetail(current.orderId, token);
  }

  Future<WaterOrderUi> _fetchWaterOrderDetail(String orderId, String token) async {
    // POST water/waterOrderDetail {orderId: <int>}（对齐 legacy，body 用数值）。
    final detail = await _transport.send(UjingRequest(
      method: 'POST',
      path: 'water/waterOrderDetail',
      appCode: 'CA',
      weex: '1.0.102',
      authToken: token,
      body: <String, Object?>{'orderId': int.tryParse(orderId) ?? orderId},
    ));
    return WaterOrderUi(
      orderId: orderId,
      orderNo: _str(detail, 'orderNo'),
      serviceSubjectName: _str(detail, 'serviceSubjectName'),
      storeName: _str(detail, 'storeName'),
      deviceNo: _str(detail, 'deviceNo'),
      orderStatus: _str(detail, 'orderStatus'),
      orderStatusName: _str(detail, 'orderStatusName',
          fallback: _str(detail, 'statusRemark')),
      statusRemark: _str(detail, 'statusRemark',
          fallback: _str(detail, 'orderStatusName')),
      warmWaterMl: _int(detail, 'warmWaterML'),
      waterSeconds: _int(detail, 'waterSeconds'),
      payment: _double(detail, 'payment'),
      payFlag: _int(detail, 'payFlag'),
    );
  }

  // ===== 洗衣 =====

  @override
  Future<WasherProgramUi> scanWasher(String qrCode) async {
    final token = _requireToken();
    // 扫码：POST devices/scanWasherCode，设备信息在 data.result（对齐 legacy scanWasher）。
    final scan = await _transport.send(UjingRequest(
      method: 'POST',
      path: 'devices/scanWasherCode',
      appCode: 'BA',
      weex: '1.1.68',
      authToken: token,
      body: <String, Object?>{'qrCode': qrCode.trim()},
    ));
    final result = _obj(scan, 'result');
    final deviceId = _str(result, 'deviceId');
    final deviceTypeId = _int(result, 'deviceTypeId');
    final createOrderEnabled = _bool(result, 'createOrderEnabled');
    final reason = _str(result, 'reason');
    final status = _str(result, 'status');

    // 不可下单：返回空 models + reason，不再拉套餐（对齐 legacy createOrderEnabled=false 分支）。
    if (!createOrderEnabled) {
      return WasherProgramUi(
        deviceId: deviceId,
        deviceNo: '',
        deviceTypeName: '',
        storeName: '',
        status: status,
        reason: reason,
        createOrderEnabled: false,
        defaultWashModelId: 0,
        models: const <WasherModelUi>[],
      );
    }

    // 拉套餐：GET app/washer/devices/program/info?deviceId=...
    final info = await _transport.send(UjingRequest(
      method: 'GET',
      path: 'app/washer/devices/program/info',
      appCode: 'BA',
      weex: '1.1.68',
      authToken: token,
      query: <String, Object?>{'deviceId': deviceId},
    ));
    final storeId = _str(info, 'storeId');
    final deviceNo = _str(info, 'deviceNo');
    final models = _parseModels(info);
    // 默认套餐：优先 workModelId=1，否则第一个（对齐 legacy defaultWashModelId）。
    var defaultModelId = 0;
    for (final m in models) {
      if (m.id == 1) {
        defaultModelId = 1;
        break;
      }
    }
    if (defaultModelId == 0 && models.isNotEmpty) {
      defaultModelId = models.first.id;
    }

    // 缓存下单必需字段（storeId/deviceTypeId），供 createWasherOrder 用。
    _programs[deviceId] = _ScannedProgram(
      deviceId: deviceId,
      deviceTypeId: deviceTypeId,
      storeId: storeId,
    );

    return WasherProgramUi(
      deviceId: deviceId,
      deviceNo: deviceNo,
      deviceTypeName: _str(info, 'deviceTypeName'),
      storeName: _str(info, 'storeName'),
      status: status,
      reason: reason,
      createOrderEnabled: true,
      defaultWashModelId: defaultModelId,
      models: models,
    );
  }

  @override
  Future<WasherOrderUi> createWasherOrder({
    required WasherProgramUi program,
    required int washModelId,
    required int temperatureId,
    int? detergentGearId,
    int? disinfectantGearId,
    required int orderSeq, // 真实后端分配 orderId，orderSeq 仅 fake 用，这里忽略。
  }) async {
    final token = _requireToken();
    final scanned = _programs[program.deviceId];
    if (scanned == null || scanned.storeId.isEmpty) {
      throw const UjingException('请先扫描洗衣机并获取套餐');
    }
    // POST orders/create（对齐 legacy createOrder body）。
    final body = <String, Object?>{
      'type': 1,
      'deviceTypeId': scanned.deviceTypeId,
      'deviceId': scanned.deviceId,
      'deviceWashModelId': washModelId,
      'storeId': scanned.storeId,
      'washTemperatureId': temperatureId,
    };
    if (detergentGearId != null) {
      body['wp_detergentGearId'] = detergentGearId;
    }
    if (disinfectantGearId != null) {
      body['wp_disinfectantGearId'] = disinfectantGearId;
    }
    final created = await _transport.send(UjingRequest(
      method: 'POST',
      path: 'orders/create',
      appCode: 'BA',
      weex: '1.1.68',
      authToken: token,
      body: body,
    ));
    final orderId = _str(created, 'orderId');
    if (orderId.isEmpty) {
      throw const UjingException('创建订单成功但没有 orderId');
    }
    return _fetchWasherOrderDetail(orderId, token);
  }

  @override
  Future<WasherOrderUi> refreshWasherOrder(WasherOrderUi order) async {
    final token = _requireToken();
    return _fetchWasherOrderDetail(order.orderId, token);
  }

  Future<WasherOrderUi> _fetchWasherOrderDetail(String orderId, String token) async {
    // GET orders/{orderId}/detail（对齐 legacy loadOrderDetail）。
    final detail = await _transport.send(UjingRequest(
      method: 'GET',
      path: 'orders/$orderId/detail',
      appCode: 'BA',
      weex: '1.1.68',
      authToken: token,
    ));
    return WasherOrderUi(
      orderId: orderId,
      deviceNo: _str(detail, 'deviceNo'),
      statusText: _str(detail, 'statusRemark', fallback: _str(detail, 'status')),
      payPrice: _formatPayPrice(detail['payPrice']),
      status: _str(detail, 'status'),
      remainTimeSeconds: _int(detail, 'remainTime'),
      countDownSeconds: _int(detail, 'countDown'),
    );
  }

  // ===== 支付 / 启停（A3 真实 HTTP + PaymentLauncher seam）=====

  @override
  Future<WasherOrderUi> payWasherOrder(WasherOrderUi order) async {
    final token = _requireToken();
    // 支付参数：GET payment/arguments(channel=alipay)（对齐 legacy paymentArguments）。
    final args = await _transport.send(UjingRequest(
      method: 'GET',
      path: 'payment/arguments',
      appCode: 'BA',
      weex: '1.1.68',
      authToken: token,
      query: <String, Object?>{
        'channel': 'alipay',
        'orderId': order.orderId,
        'couponId': '',
        'isUseRedPacket': false,
        'redPacketId': 0,
        'alipayF2FNoAds': false,
        'branchType': 0,
        'jumpToAliMini': false,
        'payVersion': 1,
      },
    ));
    final payInfo = _obj(args, 'payInfo');
    final orderInfo = _str(payInfo, 'orderInfo');
    if (orderInfo.isEmpty) {
      // 对齐 legacy：区分微信/H5/缺参，明确告知（本轮只支持支付宝）。
      if (payInfo.containsKey('prepayid') || payInfo.containsKey('prepayId')) {
        throw const UjingException('服务端返回了微信支付参数，但当前暂时只支持支付宝');
      }
      if (_str(payInfo, 'h5_url').isNotEmpty) {
        throw const UjingException('服务端返回了 H5 支付链接，但当前暂时只支持支付宝');
      }
      throw const UjingException('支付宝支付参数缺少 orderInfo');
    }

    // SDK 那一跳经 launcher（Fake 返回 9000；真机 RealPaymentLauncher 接原生 PayTask）。
    final resultStatus = await _launcher.payWithAlipay(orderInfo);

    // 支付后必须刷新订单详情（对齐 legacy「不能只信 SDK 回调」）。
    final refreshed = await _fetchWasherOrderDetail(order.orderId, token);
    if (resultStatus != FakePaymentLauncher.kAlipaySuccess) {
      throw UjingException(
        '支付未完成（resultStatus=$resultStatus），当前订单状态：${refreshed.statusText}',
        code: resultStatus,
      );
    }
    return refreshed;
  }

  @override
  Future<WasherOrderUi> startWasherOrder(
    WasherOrderUi order,
    int remainSeconds,
  ) async {
    final token = _requireToken();
    // GET orders/{orderId}/control/start（对齐 legacy startOrder）→ 刷新详情。
    await _transport.send(UjingRequest(
      method: 'GET',
      path: 'orders/${order.orderId}/control/start',
      appCode: 'BA',
      weex: '1.1.68',
      authToken: token,
    ));
    return _fetchWasherOrderDetail(order.orderId, token);
  }

  @override
  Future<WasherOrderUi> stopWasherOrder(WasherOrderUi order) async {
    final token = _requireToken();
    // GET orders/{orderId}/control/stop（对齐 legacy stopOrder）→ 刷新详情。
    await _transport.send(UjingRequest(
      method: 'GET',
      path: 'orders/${order.orderId}/control/stop',
      appCode: 'BA',
      weex: '1.1.68',
      authToken: token,
    ));
    return _fetchWasherOrderDetail(order.orderId, token);
  }

  @override
  Future<void> cancelWasherOrder(WasherOrderUi order) async {
    final token = _requireToken();
    // POST orders/{orderId}/cancel（对齐 legacy UjingApi.cancelOrder：body orderId, appCode BA）。
    // 作废服务端订单——取代旧「纯本地清 state」假取消（真机 bug：服务端订单仍活）。
    await _transport.send(UjingRequest(
      method: 'POST',
      path: 'orders/${order.orderId}/cancel',
      appCode: 'BA',
      weex: '1.1.68',
      authToken: token,
      body: <String, Object?>{'orderId': order.orderId},
    ));
  }

  // ===== 解析 helpers（容错 int/string/大小写，对齐 legacy optString/optInt）=====

  List<WasherModelUi> _parseModels(Map<String, dynamic> info) {
    final raw = info['deviceWashModel'];
    if (raw is! List) {
      return const <WasherModelUi>[];
    }
    final models = <WasherModelUi>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final map = item.cast<String, dynamic>();
      models.add(WasherModelUi(
        id: _int(map, 'workModelId'),
        name: _str(map, 'workModelName'),
        priceFen: _int(map, 'basePrice'),
        timeMinutes: _int(map, 'time'),
        additionGroups: _parseAdditions(map),
      ));
    }
    return models;
  }

  List<WasherAdditionGroupUi> _parseAdditions(Map<String, dynamic> modelJson) {
    // additionDevices 可能是直接数组，或嵌套 {washingPartnerFeature: [...]}（对齐 legacy washerAdditions）。
    final direct = modelJson['additionDevices'];
    List<dynamic>? additions;
    if (direct is List) {
      additions = direct;
    } else if (direct is Map) {
      final nested = direct['washingPartnerFeature'];
      if (nested is List) {
        additions = nested;
      }
    }
    if (additions == null) {
      return const <WasherAdditionGroupUi>[];
    }
    final groups = <WasherAdditionGroupUi>[];
    for (final a in additions) {
      if (a is! Map) {
        continue;
      }
      final map = a.cast<String, dynamic>();
      final key = _str(map, 'key');
      if (key.isEmpty) {
        continue;
      }
      final options = <WasherAdditionOptionUi>[];
      final rawOptions = map['options'];
      if (rawOptions is List) {
        for (final o in rawOptions) {
          if (o is Map) {
            final om = o.cast<String, dynamic>();
            options.add(WasherAdditionOptionUi(
              id: _int(om, 'id'),
              name: _str(om, 'name'),
              priceFen: _int(om, 'price'),
            ));
          }
        }
      }
      groups.add(WasherAdditionGroupUi(
        key: key,
        name: _str(map, 'name'),
        options: options,
      ));
    }
    return groups;
  }

  /// 洗衣二维码/设备码提取（对齐 legacy extractWaterCd：URL 取 cd= 段，否则原样）。
  static String _extractWaterCd(String qrCodeOrCd) {
    final raw = qrCodeOrCd.trim();
    if (raw.isEmpty) {
      return '';
    }
    final index = raw.indexOf('cd=');
    if (index >= 0) {
      final value = raw.substring(index + 3);
      final end = value.indexOf('&');
      return (end >= 0 ? value.substring(0, end) : value).trim();
    }
    return raw;
  }

  /// payPrice：服务端可能给数值（元）或字符串。可解析为数则格式化 ¥x.xx，否则原样透传。
  /// 与 Fake 的 formatFenAmount 展示口径的差异需真机确认（已登记为风险）。
  static String _formatPayPrice(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is num) {
      return '¥${value.toStringAsFixed(2)}';
    }
    final asNum = num.tryParse('$value');
    if (asNum != null) {
      return '¥${asNum.toStringAsFixed(2)}';
    }
    return '$value';
  }

  static String _str(Map<String, dynamic> map, String key, {String fallback = ''}) {
    final v = map[key];
    if (v == null) {
      return fallback;
    }
    if (v is String) {
      return v.isEmpty ? fallback : v;
    }
    return '$v';
  }

  static String _strAny(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final v = map[key];
      if (v != null && '$v'.isNotEmpty) {
        return '$v';
      }
    }
    return '';
  }

  static int _int(Map<String, dynamic> map, String key, {int fallback = 0}) {
    final v = map[key];
    if (v is num) {
      return v.toInt();
    }
    if (v is String) {
      return int.tryParse(v) ?? fallback;
    }
    return fallback;
  }

  static double _double(Map<String, dynamic> map, String key, {double fallback = 0}) {
    final v = map[key];
    if (v is num) {
      return v.toDouble();
    }
    if (v is String) {
      return double.tryParse(v) ?? fallback;
    }
    return fallback;
  }

  static bool _bool(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v is bool) {
      return v;
    }
    if (v is num) {
      return v != 0;
    }
    if (v is String) {
      return v.toLowerCase() == 'true' || v == '1';
    }
    return false;
  }

  static Map<String, dynamic> _obj(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v is Map) {
      return v.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }
}

/// 已扫套餐的下单必需字段缓存（共享 UI 模型不含 storeId/deviceTypeId）。
class _ScannedProgram {
  const _ScannedProgram({
    required this.deviceId,
    required this.deviceTypeId,
    required this.storeId,
  });

  final String deviceId;
  final int deviceTypeId;
  final String storeId;
}
