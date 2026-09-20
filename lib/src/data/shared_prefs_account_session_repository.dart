// SharedPreferences-backed AccountSessionRepository (no visual constants).

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../runtime/models/account_session.dart';
import 'account_session_repository.dart';
import 'recoverable_json.dart';

/// 基于 shared_preferences 的账号 session 持久化实现（Android + iOS）。
class SharedPrefsAccountSessionRepository implements AccountSessionRepository {
  Future<void> _save(SharedPreferences prefs, String key, String value) async {
    if (!await prefs.setString(key, value)) throw StateError('账号状态保存失败');
  }

  @override
  Future<void> clearZhuli() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(_zhuliPhoneKey)) throw StateError('账号状态保存失败');
  }

  @override
  Future<void> clearUjing() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _ujingMobileKey,
      _ujingUserIdKey,
      _ujingServiceSubjectKey
    ]) {
      if (!await prefs.remove(key)) throw StateError('账号状态保存失败');
    }
  }

  @override
  Future<void> clearShower798() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [_s798MobileKey, _s798UidKey, _s798EidKey]) {
      if (!await prefs.remove(key)) throw StateError('账号状态保存失败');
    }
  }

  SharedPrefsAccountSessionRepository();

  static const String _zhuliPhoneKey = 'zhuli_phone';
  static const String _zhuliDeviceCodeKey = 'zhuli_device_code';
  static const String _ujingMobileKey = 'ujing_mobile';
  static const String _ujingUserIdKey = 'ujing_user_id';
  static const String _ujingServiceSubjectKey = 'ujing_service_subject_id';
  // P3 798：session 三字段 + 设备列表 JSON + 当前设备 id。
  static const String _s798MobileKey = 'shower798_mobile';
  static const String _s798UidKey = 'shower798_uid';
  static const String _s798EidKey = 'shower798_eid';
  static const String _s798DevicesKey = 'shower798_devices_json';
  static const String _s798CurrentDeviceKey = 'shower798_current_device_id';

  @override
  Future<ZhuliSession?> loadZhuli() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_zhuliPhoneKey);
    if ((phone == null || phone.isEmpty) &&
        (prefs.getString(_zhuliDeviceCodeKey) ?? '').isEmpty) {
      return null;
    }
    return ZhuliSession(
      phone: phone ?? '',
      deviceCode: prefs.getString(_zhuliDeviceCodeKey) ?? '',
    );
  }

  @override
  Future<void> saveZhuli(ZhuliSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await _save(prefs, _zhuliDeviceCodeKey, session.deviceCode);
    await _save(prefs, _zhuliPhoneKey, session.phone);
  }

  @override
  Future<UjingAccountUi?> loadUjing() async {
    final prefs = await SharedPreferences.getInstance();
    final mobile = prefs.getString(_ujingMobileKey);
    if (mobile == null || mobile.isEmpty) {
      return null;
    }
    return UjingAccountUi(
      mobile: mobile,
      userId: prefs.getString(_ujingUserIdKey) ?? '',
      serviceSubjectId: prefs.getString(_ujingServiceSubjectKey) ?? '',
    );
  }

  @override
  Future<void> saveUjing(UjingAccountUi account) async {
    final prefs = await SharedPreferences.getInstance();
    await _save(prefs, _ujingUserIdKey, account.userId);
    await _save(prefs, _ujingServiceSubjectKey, account.serviceSubjectId);
    await _save(prefs, _ujingMobileKey, account.mobile);
  }

  @override
  Future<Shower798Persisted?> loadShower798() async {
    final prefs = await SharedPreferences.getInstance();
    final mobile = prefs.getString(_s798MobileKey);
    if (mobile == null || mobile.isEmpty) {
      return null;
    }
    final devices = <Shower798DeviceUi>[];
    if (prefs.containsKey(_s798DevicesKey)) {
      final decoded = await readRecoverableJson(prefs, _s798DevicesKey, (raw) {
        final value = jsonDecode(raw);
        if (value is! List || value.any((item) => item is! Map)) {
          throw const FormatException('Invalid 798 devices');
        }
        return value;
      });
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            devices.add(
              Shower798DeviceUi(
                id: (item['id'] ?? '').toString(),
                name: (item['name'] ?? '').toString(),
                lastStatus: (item['lastStatus'] ?? '待机').toString(),
              ),
            );
          }
        }
      }
    }
    return Shower798Persisted(
      account: Shower798AccountUi(
        mobile: mobile,
        uid: prefs.getString(_s798UidKey) ?? '',
        eid: prefs.getString(_s798EidKey) ?? '',
      ),
      devices: devices,
      currentDeviceId: prefs.getString(_s798CurrentDeviceKey) ?? '',
    );
  }

  @override
  Future<void> saveShower798(Shower798Persisted data) async {
    final prefs = await SharedPreferences.getInstance();
    await _save(prefs, _s798UidKey, data.account.uid);
    await _save(prefs, _s798EidKey, data.account.eid);
    await _save(prefs, _s798CurrentDeviceKey, data.currentDeviceId);
    final devicesJson = jsonEncode(
      data.devices
          .map((d) => {
                'id': d.id,
                'name': d.name,
                'lastStatus': d.lastStatus,
              })
          .toList(),
    );
    await _save(prefs, _s798DevicesKey, devicesJson);
    await _save(prefs, _s798MobileKey, data.account.mobile);
  }
}
