// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Real 慧生活798 adapter (no visual constants). Orchestrates the token-auth HTTP endpoints for
// captcha / sms / login / devices / start / stop / idle, faithful to legacy Shower798RuntimeAdapter.kt.
// HTTP (build request + parse) is testable via fixtures through the injected Shower798Transport;
// the real socket lives in IoShower798Transport (verified ON-DEVICE by the user). NOT enabled by
// default (main line = FakeShower798Adapter). Pure HTTP — no BLE, no signing.
//
// 真机接入（用户）：注入 RealShower798Adapter(transport: IoShower798Transport())，用真实 798 账号走
// 验证码 → 登录 → 设备列表/增删 → 开关洗浴。doubleRandom/timestamp 由客户端生成（真机用真实值）。

import '../../runtime/models/account_session.dart';
import 'shower798_adapter.dart';
import 'shower798_transport.dart';

/// 真实 798 适配器（S798）。有状态：登录后持 token（对齐 legacy CachedSession.token）。
/// doubleRandom/timestamp 可注入 → captcha 请求确定性（默认时钟派生）。
class RealShower798Adapter implements IShower798Adapter {
  RealShower798Adapter({
    required Shower798Transport transport,
    String Function()? doubleRandom,
    String Function()? timestamp,
    String? token,
    void Function(String message)? log,
  })  : _transport = transport,
        _doubleRandom = doubleRandom ?? _defaultDoubleRandom,
        _timestamp = timestamp ?? _defaultTimestamp,
        _token = token,
        _log = log ?? _noop;

  static void _noop(String _) {}

  /// M-REAL 诊断日志埋点（对齐 legacy [shower798-runtime] AppLogStore.append）。默认 no-op。
  final void Function(String message) _log;

  final Shower798Transport _transport;
  final String Function() _doubleRandom;
  final String Function() _timestamp;

  /// PTOK：构造可注入已持久化 token（重启免重登）；登录成功后由 action 层读 [lastToken] 落盘。
  String? _token;

  /// PTOK：当前 token（供 action 层登录成功后持久化；未登录为 null）。
  String? get lastToken => _token;

  /// RELOG：服务端拒绝当前 token 时由 action 层调用，清内存凭证（配合 secure.clear + 账号 state 清空）。
  void invalidateAuth() {
    _token = null;
  }

  String _requireToken() {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw const Shower798Exception('请先登录 798 洗浴账号');
    }
    return token;
  }

  @override
  Future<Shower798CaptchaData> requestCaptcha() async {
    // GET /captcha/?s=<doubleRandom>&r=<timestamp> → 图片字节 → base64（对齐 legacy getCaptcha）。
    final s = _doubleRandom();
    final r = _timestamp();
    final base64 = await _transport.getImageBase64(Shower798Request(
      method: 'GET',
      path: 'captcha/',
      query: <String, Object?>{'s': s, 'r': r},
    ));
    return Shower798CaptchaData(imageBase64: base64, doubleRandom: s, timestamp: r);
  }

  @override
  Future<void> sendSmsCode({
    required String doubleRandom,
    required String imageCaptcha,
    required String phone,
  }) async {
    // POST /acc/login/code {s, authCode, un}（对齐 legacy sendSmsCode）。
    await _transport.send(Shower798Request(
      method: 'POST',
      path: 'acc/login/code',
      body: <String, Object?>{
        's': doubleRandom,
        'authCode': imageCaptcha.trim(),
        'un': phone.trim(),
      },
    ));
  }

  @override
  Future<Shower798SessionData> login(String phone, String smsCode) async {
    // POST /acc/login {openCode, authCode, un, cid} → data.al.uid/eid/token（对齐 legacy login）。
    final resp = await _transport.send(Shower798Request(
      method: 'POST',
      path: 'acc/login',
      body: <String, Object?>{
        'openCode': '',
        'authCode': smsCode.trim(),
        'un': phone.trim(),
        'cid': 'flandre-shuiyi-android',
      },
    ));
    final al = _obj(_obj(resp, 'data'), 'al');
    final token = _str(al, 'token');
    if (token.isEmpty) {
      throw const Shower798Exception('登录返回缺少账号信息');
    }
    _token = token;
    _log('798 洗浴登录成功 phone=${phone.trim()}');
    return Shower798SessionData(
      phone: phone.trim(),
      uid: _str(al, 'uid'),
      eid: _str(al, 'eid'),
      token: token,
    );
  }

  @override
  Future<List<Shower798DeviceUi>> loadDevices() async {
    // GET /ui/app/master → data.favos（对齐 legacy loadDevices；反序）。
    final resp = await _transport.send(Shower798Request(
      method: 'GET',
      path: 'ui/app/master',
      token: _requireToken(),
    ));
    final data = _obj(resp, 'data');
    if (!data.containsKey('account')) {
      // account 缺失 = 登录失效（对齐 legacy logout + 抛错）。authInvalid 触发 RELOG 同步清 secure。
      _token = null;
      throw const Shower798Exception('798 洗浴登录已失效，请重新登录',
          authInvalid: true);
    }
    final favos = data['favos'];
    final devices = <Shower798DeviceUi>[];
    if (favos is List) {
      for (final row in favos) {
        if (row is! Map) {
          continue;
        }
        final m = row.cast<String, dynamic>();
        final id = _str(m, 'id');
        if (id.isEmpty) {
          continue;
        }
        final name = _str(m, 'name');
        devices.add(Shower798DeviceUi(
          id: id,
          name: name.isEmpty ? '洗浴设备 $id' : name,
        ));
      }
    }
    return devices.reversed.toList();
  }

  @override
  Future<void> addDevice(String deviceId) async {
    await _transport.send(Shower798Request(
      method: 'GET',
      path: 'dev/favo',
      query: <String, Object?>{'did': deviceId.trim(), 'remove': false},
      token: _requireToken(),
    ));
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
    await _transport.send(Shower798Request(
      method: 'GET',
      path: 'dev/favo',
      query: <String, Object?>{'did': deviceId.trim(), 'remove': true},
      token: _requireToken(),
    ));
  }

  @override
  Future<void> startShower(String deviceId) async {
    // GET /dev/start?did=&upgrade=true&ptype=21&args=&rcp=false&cnt=1（对齐 legacy startShower）。
    await _transport.send(Shower798Request(
      method: 'GET',
      path: 'dev/start',
      query: <String, Object?>{
        'did': deviceId,
        'upgrade': true,
        'ptype': 21,
        'args': '',
        'rcp': false,
        'cnt': 1,
      },
      token: _requireToken(),
    ));
  }

  @override
  Future<void> stopShower(String deviceId) async {
    await _transport.send(Shower798Request(
      method: 'GET',
      path: 'dev/end',
      query: <String, Object?>{'did': deviceId, 'rcp': false},
      token: _requireToken(),
    ));
  }

  @override
  Future<bool> isDeviceIdle(String deviceId) async {
    // GET /ui/app/dev/status → gene.status==99 或 subs[0].status==0（对齐 legacy isDeviceIdle）。
    final resp = await _transport.send(Shower798Request(
      method: 'GET',
      path: 'ui/app/dev/status',
      query: <String, Object?>{'did': deviceId, 'more': false},
      token: _requireToken(),
    ));
    final device = _obj(_obj(resp, 'data'), 'device');
    final geneStatus = _int(_obj(device, 'gene'), 'status', fallback: -1);
    var subStatus = -1;
    final subs = device['subs'];
    if (subs is List && subs.isNotEmpty && subs.first is Map) {
      subStatus = _int((subs.first as Map).cast<String, dynamic>(), 'status',
          fallback: -1);
    }
    return geneStatus == 99 || subStatus == 0;
  }

  // ===== helpers =====

  static String _defaultTimestamp() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  static String _defaultDoubleRandom() {
    // 对齐 legacy「doubleRandom」用途（非加密）；用时钟派生避免 Math.random。
    final a = DateTime.now().microsecondsSinceEpoch & 0xffffff;
    final b = (DateTime.now().microsecondsSinceEpoch >> 12) & 0xffffff;
    return '$a$b';
  }

  static Map<String, dynamic> _obj(Map<String, dynamic> map, String key) {
    final v = map[key];
    if (v is Map) {
      return v.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  static String _str(Map<String, dynamic> map, String key,
      {String fallback = ''}) {
    final v = map[key];
    if (v == null) {
      return fallback;
    }
    if (v is String) {
      return v.isEmpty ? fallback : v;
    }
    return '$v';
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
}
