/// 有 MAC 时必须匹配 MAC，不能因同名或 XN 前缀放宽到其它设备。
bool matchesZhuliBleTarget(
    {required String expectedName,
    required String expectedMac,
    required String name,
    required String address}) {
  String mac(String value) =>
      value.trim().replaceAll(RegExp('[:-]'), '').toLowerCase();
  if (expectedMac.trim().isNotEmpty) return mac(expectedMac) == mac(address);
  return expectedName.trim().isNotEmpty && expectedName.trim() == name.trim();
}
