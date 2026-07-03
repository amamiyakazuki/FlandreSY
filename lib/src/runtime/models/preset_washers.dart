// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Pure data (no visual constants); preset list 1:1 from legacy ShuiScreens.kt haiqiPresetWashers.

/// 海七宿舍预置洗衣机。二维码 uuid 与 legacy `ShuiScreens.kt` 的
/// `haiqiPresetWashers` 完全一致，便于后续扫码复用同一设备。
class PresetWasherDevice {
  const PresetWasherDevice({required this.name, required this.qrCode});

  final String name;
  final String qrCode;
}

const List<PresetWasherDevice> haiqiPresetWashers = <PresetWasherDevice>[
  PresetWasherDevice(
    name: '海七-二楼左',
    qrCode:
        'http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007107',
  ),
  PresetWasherDevice(
    name: '海七-二楼中',
    qrCode:
        'http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007129',
  ),
  PresetWasherDevice(
    name: '海七-二楼右',
    qrCode:
        'http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007119',
  ),
  PresetWasherDevice(
    name: '海七-三楼左',
    qrCode:
        'http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007230',
  ),
  PresetWasherDevice(
    name: '海七-三楼中',
    qrCode:
        'http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007196',
  ),
  PresetWasherDevice(
    name: '海七-三楼右',
    qrCode:
        'http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A0007604202108140003053',
  ),
  PresetWasherDevice(
    name: '海七-四楼左',
    qrCode:
        'http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A0007604202108140002704',
  ),
  PresetWasherDevice(
    name: '海七-四楼中',
    qrCode:
        'http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007239',
  ),
  PresetWasherDevice(
    name: '海七-四楼右',
    qrCode:
        'http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A0007604202108140002884',
  ),
  PresetWasherDevice(
    name: '海七-五楼左',
    qrCode:
        'http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A0007604202108140003091',
  ),
  PresetWasherDevice(
    name: '海七-五楼中',
    qrCode:
        'http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A0007604202108140003074',
  ),
  PresetWasherDevice(
    name: '海七-五楼右',
    qrCode:
        'http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007226',
  ),
  PresetWasherDevice(
    name: '海七-六楼左',
    qrCode:
        'http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007220',
  ),
  PresetWasherDevice(
    name: '海七-六楼中',
    qrCode:
        'http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007382',
  ),
  PresetWasherDevice(
    name: '海七-六楼右',
    qrCode:
        'http://app.littleswan.com/u_download.html?type=Ujing&uuid=0000000000000A1234567202208070007189',
  ),
];
