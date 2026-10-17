/// Diagnostics accept known events, not arbitrary response/exception strings.
/// This is deliberately an allowlist: regex masking cannot reliably identify
/// credentials in unknown formats. Add new event schemas here with their tests.
class DiagnosticPrivacy {
  static const omitted = '非结构化诊断内容已省略';
  static const _tags = {
    'ujing',
    'hotwater',
    'shower798',
    'washer',
    'water',
    'auth',
    'storage',
    'flutter-error',
  };
  static String tag(String value) =>
      _tags.contains(value) ? value : 'diagnostic';

  static const _events = {
    omitted,
    'U净登录成功',
    '住理登录成功',
    '798 洗浴登录成功',
    '启动支付宝支付',
    '洗衣启动请求已确认，等待订单详情',
    '洗衣停止请求已确认，等待订单详情',
    '热水启动完成',
    '热水已关闭',
    '本地热水凭据清理失败',
    '合并重复在途控制',
    '旧热水凭据清理失败',
    '本地数据恢复存在异常',
  };
  static const _failures = {
    'Flutter异常',
    '失效凭据清理失败',
    '设备保存失败',
    '权限引导状态保存失败',
    '热水操作失败',
    '旧订单自动归属保存失败',
    '订单操作或保存失败',
    '失效后订单保全保存失败',
    '住理登录保存失败',
    '设备码保存失败',
    '登录失败后清理失败',
    '798设备操作失败',
    '订单创建或保存失败',
    '订单查询或保存失败',
    'U净 凭据读取失败',
    '住理 凭据读取失败',
    '798 凭据读取失败',
  };
  static const _types = {
    'StateError',
    'FormatException',
    'TimeoutException',
    'SocketException',
    'HttpException',
    'HandshakeException',
    'TlsException',
    'ClientException',
    'FileSystemException',
    'PlatformException',
    'FlutterError',
    'AssertionError',
    'UjingException',
    'HotwaterException',
    'Shower798Exception',
    'Exception',
    'TypeError',
    '_TypeError',
    'RangeError',
    'ArgumentError',
    '其他异常',
  };
  static String errorType(Object error) => type(error.runtimeType.toString());
  static String type(String value) => _types.contains(value) ? value : '其他异常';
  static String code(String value) => RegExp(r'^-?\d{1,4}$').hasMatch(value) ||
          const {'api_sign_error', 'error_args', 'unknown'}.contains(value)
      ? value
      : 'unknown';

  static String endpoint(String value) => const {
        'device/get_by_id',
        'device/ble/create_hand_shake_cmd',
        'device/ble/heart_shark_response',
        'device/ble/create_rate_cmd',
        'device/ble/create_history_order_cmd',
        'consume/ble/end_consume_response',
        'consume/create_order',
        'consume/ble/start_consume_response',
        'consume/ble/create_end_consume_cmd',
        'consume/list_record_by_staffid',
      }.contains(value)
          ? value
          : 'unknown';

  static String paymentStatus(String value) => const {
        '9000',
        '8000',
        '4000',
        '5000',
        '6001',
        '6002',
        '6004',
      }.contains(value)
          ? value
          : 'unknown';

  static String message(String value) {
    if (_events.contains(value)) return value;
    final failure =
        RegExp(r'^(.+) type=([^\s，]+)(?:，需重新登录)?$').firstMatch(value);
    if (failure != null && _failures.contains(failure[1])) {
      return '${failure[1]} type=${type(failure[2]!)}';
    }
    final stage = RegExp(r'^热水启动阶段=(.+)$').firstMatch(value);
    if (stage != null &&
        const {
          'device_query',
          'ble_scan_connect',
          'handshake_command',
          'handshake_confirm',
          'rate_command',
          'history_command',
          'order_create',
          'start_command_confirm',
          'completed',
        }.contains(stage[1])) {
      return value;
    }
    if (RegExp(r'^忽略重复启动 phase=(preparing|starting|active|uncertain)$')
        .hasMatch(value)) {
      return value;
    }
    final payment = RegExp(r'^支付宝返回 resultStatus=(.+)$').firstMatch(value);
    if (payment != null) {
      final status = paymentStatus(payment[1]!);
      return '支付宝返回 resultStatus=$status';
    }
    final login =
        RegExp(r'^798登录失败 stage=(登录请求|登录后设备列表读取|登录信息保存|旧数据登录确认保存) type=(.+)$')
            .firstMatch(value);
    if (login != null) {
      return '798登录失败 stage=${login[1]} type=${type(login[2]!)}';
    }
    final business =
        RegExp(r'^住理接口失败 endpoint=([^ ]+) (code|type)=(.+)$').firstMatch(value);
    if (business != null) {
      return '住理接口失败 endpoint=${endpoint(business[1]!)} ${business[2]}=${business[2] == 'code' ? code(business[3]!) : type(business[3]!)}';
    }
    return omitted;
  }

  /// Revalidate persisted input and copy output. Redact before limiting size,
  /// and keep complete lines so a truncated secret cannot evade filtering.
  static String history(String value) {
    final lines = <String>[];
    for (final line in value.split('\n')) {
      if (line.isEmpty) continue;
      final match = RegExp(r'^\[(\d{2}:\d{2}:\d{2})\] \[([^\]]+)\] (.*)$')
          .firstMatch(line);
      lines.add(match == null
          ? '[00:00:00] [diagnostic] $omitted\n'
          : '[${match[1]}] [${tag(match[2]!)}] ${message(match[3]!)}\n');
    }
    var total = lines.fold<int>(0, (sum, line) => sum + line.length);
    var start = 0;
    while (total > 16000 && start < lines.length) {
      total -= lines[start++].length;
    }
    return lines.skip(start).join();
  }
}
