import 'dart:typed_data';

/// FNV-1a + LCG stream. Must match tool/encode_cinder_values.dart.
const List<int> _seed = <int>[
  0x71, 0x58, 0x2B, 0x63, 0x56, 0x39, 0x4B, 0x6E, 0x31, 0x44, 0x73, 0x37,
];

Uint8List _stream(int length) {
  var fnv = 2166136261;
  for (final b in _seed) {
    fnv = ((fnv ^ b) * 16777619) & 0xffffffff;
  }
  var state = fnv;
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    state = (state * 48271 + 9973) & 0xffffffff;
    out[i] = (state >> 16) & 0xff;
  }
  return out;
}

int _mix(int i) => (_seed[i % _seed.length] + i * 31) & 0xff;

String liftVeil(List<int> encoded) {
  if (encoded.isEmpty) return '';
  final stream = _stream(encoded.length);
  final plain = Uint8List(encoded.length);
  for (var i = 0; i < encoded.length; i++) {
    plain[i] = (encoded[i] ^ stream[i] ^ _mix(i)) & 0xff;
  }
  return String.fromCharCodes(plain);
}
