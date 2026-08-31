import 'dart:typed_data';

/// Mixing seed — unique to Embercrest. Must match tool/encode_rift_values.dart.
const List<int> _riftSeed = <int>[
  0x52, 0x31, 0x44, 0x67, 0x65, 0x23, 0x4D, 0x61, 0x67, 0x6D, 0x61, 0x39,
];

Uint8List _pad(int length) {
  final out = Uint8List(length);
  var acc = 0xA5;
  for (var i = 0; i < length; i++) {
    acc = (acc * 131 + _riftSeed[i % _riftSeed.length] + i * 17) & 0xffff;
    out[i] = ((acc >> 8) ^ acc ^ (i * 41)) & 0xff;
  }
  return out;
}

int _twist(int i) =>
    (_riftSeed[(i * 3) % _riftSeed.length] + (i * 97) + 13) & 0xff;

/// Restores a string sealed by `sealRift` in the encode tool.
String unsealRift(List<int> encoded) {
  if (encoded.isEmpty) return '';
  final pad = _pad(encoded.length);
  final plain = Uint8List(encoded.length);
  for (var i = 0; i < encoded.length; i++) {
    plain[i] = (encoded[i] ^ pad[i] ^ _twist(i)) & 0xff;
  }
  return String.fromCharCodes(plain);
}
