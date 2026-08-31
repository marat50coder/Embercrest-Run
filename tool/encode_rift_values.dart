// ignore_for_file: avoid_print

import 'dart:typed_data';

/// Seed for Embercrest Run — keep in sync with lib/ridgeline/codec.dart.
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

List<int> sealRift(String value) {
  final bytes = Uint8List.fromList(value.codeUnits);
  final pad = _pad(bytes.length);
  return List<int>.generate(
    bytes.length,
    (i) => (bytes[i] ^ pad[i] ^ _twist(i)) & 0xff,
  );
}

String unsealRift(List<int> encoded) {
  final pad = _pad(encoded.length);
  return String.fromCharCodes(
    List<int>.generate(
      encoded.length,
      (i) => (encoded[i] ^ pad[i] ^ _twist(i)) & 0xff,
    ),
  );
}

void main() {
  const values = <String, String>{
    'config': 'https://embercrestrun.com/config.php',
    'privacy': 'https://embercrestrun.com/privacy-policy.html',
    'support': 'https://embercrestrun.com/support.html',
    'gcd': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
    'webkit': '605.1.15',
    'safari': '18.6',
    'safariTail': '605.1',
    'appsFlyerDevKey': 'EV4eqZwVm2vYob7fghRgdF',
    'firebaseProjectNumber': '173824680995',
    'oneLinkHost': 'embercrest.onelink.me',
  };

  for (final entry in values.entries) {
    final encoded = sealRift(entry.value);
    print('${entry.key}: <int>[${encoded.join(', ')}]');
    if (unsealRift(encoded) != entry.value) {
      throw StateError('Round-trip failed for ${entry.key}');
    }
  }
  print('VERIFY: all values round-tripped');
}
