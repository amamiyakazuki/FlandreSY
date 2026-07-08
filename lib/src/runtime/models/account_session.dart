// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Account session models (no visual constants). Field names align 1:1 with legacy
// ShuiRuntime.kt UjingAccountUi + hotwaterPhone/hotwaterDeviceCode (Zhuli).

import 'package:flutter/foundation.dart';

/// 账号类型（对齐 legacy `AccountKind`）。798 登录在 P3 实现。
enum AccountKind { zhuli, ujing, shower798 }

/// 住理生活账号 session（对齐 legacy hotwaterPhone + hotwaterDeviceCode）。
@immutable
class ZhuliSession {
  const ZhuliSession({required this.phone, this.deviceCode = ''});

  final String phone;
  final String deviceCode;

  bool get isLoggedIn => phone.trim().isNotEmpty;

  ZhuliSession copyWith({String? phone, String? deviceCode}) {
    return ZhuliSession(
      phone: phone ?? this.phone,
      deviceCode: deviceCode ?? this.deviceCode,
    );
  }
}

/// U净账号 session（对齐 legacy `UjingAccountUi`：mobile/userId/serviceSubjectId）。
@immutable
class UjingAccountUi {
  const UjingAccountUi({
    required this.mobile,
    required this.userId,
    required this.serviceSubjectId,
  });

  final String mobile;
  final String userId;
  final String serviceSubjectId;
}

/// 慧生活798 账号 session（对齐 legacy `Shower798AccountUi`：mobile/uid/eid）。
@immutable
class Shower798AccountUi {
  const Shower798AccountUi({
    required this.mobile,
    required this.uid,
    required this.eid,
  });

  final String mobile;
  final String uid;
  final String eid;
}

/// 慧生活798 设备（对齐 legacy `Shower798DeviceUi`：id/name/lastStatus）。
@immutable
class Shower798DeviceUi {
  const Shower798DeviceUi({
    required this.id,
    required this.name,
    this.lastStatus = '待机',
  });

  final String id;
  final String name;
  final String lastStatus;
}
