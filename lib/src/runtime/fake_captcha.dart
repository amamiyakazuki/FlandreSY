// GAL REVIEW REQUIRED BEFORE NEXT MODULE
// See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md
// Fake captcha image generator (no visual constants — produces raw PNG bytes as base64).
// The base64 decode + Image.memory render path in the UI is REAL; only the image content is fake,
// so this is ready to swap for a real 798 getCaptcha() response later.

import 'dart:convert';
import 'dart:typed_data';

/// 生成一张「真实合法」的 fake 图形验证码 PNG 的 base64。
/// 由刷新计数 [index] 派生颜色（无 Math.random → golden 可重现）。
/// 真实接入时，用 798 getCaptcha() 返回的 base64 替换即可，UI 解码链路不变。
String fakeCaptchaBase64(int index) {
  // 调色板（走原始 RGB 字节，非 UI 视觉常量；仅用于生成假图内容）。
  const palette = <List<int>>[
    [239, 64, 86], // 红
    [77, 141, 235], // 蓝
    [255, 169, 58], // 橙
    [125, 191, 76], // 绿
  ];
  final rgb = palette[index % palette.length];
  return _solidPngBase64(width: 120, height: 44, r: rgb[0], g: rgb[1], b: rgb[2]);
}

/// 构造一张纯色 RGBA PNG 并返回 base64。手写 PNG（IHDR + IDAT[zlib stored] + IEND）。
String _solidPngBase64({
  required int width,
  required int height,
  required int r,
  required int g,
  required int b,
}) {
  final bytes = BytesBuilder();
  // PNG 签名。
  bytes.add(const [137, 80, 78, 71, 13, 10, 26, 10]);

  // IHDR：宽高 + 8bit + colorType 6(RGBA)。
  final ihdr = BytesBuilder()
    ..add(_u32(width))
    ..add(_u32(height))
    ..addByte(8)
    ..addByte(6)
    ..addByte(0)
    ..addByte(0)
    ..addByte(0);
  _chunk(bytes, 'IHDR', ihdr.toBytes());

  // 原始像素：每行 1 字节 filter(0) + width*4 RGBA。
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0);
    for (var x = 0; x < width; x++) {
      raw
        ..addByte(r)
        ..addByte(g)
        ..addByte(b)
        ..addByte(255);
    }
  }
  final rawBytes = raw.toBytes();

  // zlib「stored」封装（未压缩）：2 字节头 + 若干 stored block + Adler32。
  final zlib = BytesBuilder()
    ..addByte(0x78)
    ..addByte(0x01)
    ..add(_storedDeflate(rawBytes))
    ..add(_u32(_adler32(rawBytes)));
  _chunk(bytes, 'IDAT', zlib.toBytes());

  _chunk(bytes, 'IEND', Uint8List(0));
  return base64Encode(bytes.toBytes());
}

/// deflate「stored」块（type=00），每块最多 65535 字节。
Uint8List _storedDeflate(Uint8List data) {
  final out = BytesBuilder();
  var offset = 0;
  while (offset < data.length) {
    final len = (data.length - offset).clamp(0, 65535);
    final isFinal = offset + len >= data.length;
    out.addByte(isFinal ? 1 : 0);
    out
      ..addByte(len & 0xFF)
      ..addByte((len >> 8) & 0xFF)
      ..addByte((~len) & 0xFF)
      ..addByte(((~len) >> 8) & 0xFF);
    out.add(data.sublist(offset, offset + len));
    offset += len;
  }
  if (data.isEmpty) {
    out
      ..addByte(1)
      ..addByte(0)
      ..addByte(0)
      ..addByte(0xFF)
      ..addByte(0xFF);
  }
  return out.toBytes();
}

void _chunk(BytesBuilder out, String type, Uint8List data) {
  final typeBytes = ascii.encode(type);
  out.add(_u32(data.length));
  out.add(typeBytes);
  out.add(data);
  final crcInput = BytesBuilder()
    ..add(typeBytes)
    ..add(data);
  out.add(_u32(_crc32(crcInput.toBytes())));
}

Uint8List _u32(int v) => Uint8List(4)
  ..[0] = (v >> 24) & 0xFF
  ..[1] = (v >> 16) & 0xFF
  ..[2] = (v >> 8) & 0xFF
  ..[3] = v & 0xFF;

int _adler32(Uint8List data) {
  var a = 1;
  var b = 0;
  for (final byte in data) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  return (b << 16) | a;
}

int _crc32(Uint8List data) {
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}
