import 'dart:typed_data';

/// Cipher seed — UNIQUE per app. Keep in sync with
/// tool/encode_ember_values.dart. Changing this invalidates every encoded
/// byte array in ember_gate_config.dart (re-run the tool afterwards).
const List<int> _emberSalt = <int>[
  0x45, 0x6D, 0x62, 0x33, 0x72, 0x43, 0x72, 0x23, 0x73, 0x74, 0x21, 0x37,
];

/// RC4-style keystream keyed by the salt (KSA + PRGA).
Uint8List _emberStream(int length) {
  final s = List<int>.generate(256, (i) => i);
  var j = 0;
  for (var i = 0; i < 256; i++) {
    j = (j + s[i] + _emberSalt[i % _emberSalt.length]) & 0xff;
    final t = s[i];
    s[i] = s[j];
    s[j] = t;
  }
  final out = Uint8List(length);
  var a = 0;
  var b = 0;
  for (var i = 0; i < length; i++) {
    a = (a + 1) & 0xff;
    b = (b + s[a]) & 0xff;
    final t = s[a];
    s[a] = s[b];
    s[b] = t;
    out[i] = s[(s[a] + s[b]) & 0xff];
  }
  return out;
}

int _rot(int i) => (_emberSalt[i % _emberSalt.length] ^ (i * 53)) & 0xff;

/// Decodes a byte array produced by `fold(...)` in the encode tool back into
/// its plaintext string.
String thawEmbers(List<int> encoded) {
  if (encoded.isEmpty) return '';
  final stream = _emberStream(encoded.length);
  final plain = Uint8List(encoded.length);
  for (var i = 0; i < encoded.length; i++) {
    plain[i] = (encoded[i] - stream[i] - _rot(i)) & 0xff;
  }
  return String.fromCharCodes(plain);
}
