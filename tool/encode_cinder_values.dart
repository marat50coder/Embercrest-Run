// ignore_for_file: avoid_print

import 'dart:typed_data';

/// FNV-1a seed + LCG stream. Keep in sync with lib/cinder/pact/seal.dart.
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

List<int> seal(String value) {
  final bytes = Uint8List.fromList(value.codeUnits);
  final stream = _stream(bytes.length);
  return List<int>.generate(
    bytes.length,
    (i) => (bytes[i] ^ stream[i] ^ _mix(i)) & 0xff,
  );
}

String lift(List<int> encoded) {
  final stream = _stream(encoded.length);
  return String.fromCharCodes(
    List<int>.generate(
      encoded.length,
      (i) => (encoded[i] ^ stream[i] ^ _mix(i)) & 0xff,
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
    'safari': '18.4',
    'safariTail': '604.1',
    'appsFlyerDevKey': 'EV4eqZwVm2vYob7fghRgdF',
    'firebaseProjectNumber': '173824680995',
    'oneLinkHost': 'embercrest.onelink.me',
    'uaHead': 'Mozilla/5.0 (iPhone; CPU iPhone OS ',
    'uaMid1': ' like Mac OS X) AppleWebKit/',
    'uaMid2': ' (KHTML, like Gecko) Version/',
    'uaMid3': ' Mobile/15E148 Safari/',
    'uaApp': ' appid/',
    'uaName': ' appname/',
    'paidStatus': 'Non-organic',
  };

  for (final entry in values.entries) {
    final encoded = seal(entry.value);
    print('${entry.key}: <int>[${encoded.join(', ')}]');
    if (lift(encoded) != entry.value) {
      throw StateError('Round-trip failed for ${entry.key}');
    }
  }
  print('VERIFY: all values round-tripped');
}
