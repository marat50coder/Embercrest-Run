// ignore_for_file: avoid_print

import 'dart:typed_data';

/// Cipher seed for Embercrest Run — UNIQUE to this app (see fingerprint rules).
/// Keep this in sync with lib/emberway/core/ember_cipher.dart `_emberSalt`.
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

/// Position rotation combined with the keystream, so identical plaintext
/// prefixes across two secrets never produce identical byte prefixes.
int _rot(int i) => (_emberSalt[i % _emberSalt.length] ^ (i * 53)) & 0xff;

List<int> fold(String value) {
  final bytes = Uint8List.fromList(value.codeUnits);
  final stream = _emberStream(bytes.length);
  return List<int>.generate(
    bytes.length,
    (i) => (bytes[i] + stream[i] + _rot(i)) & 0xff,
  );
}

String unfold(List<int> encoded) {
  final stream = _emberStream(encoded.length);
  return String.fromCharCodes(
    List<int>.generate(
      encoded.length,
      (i) => (encoded[i] - stream[i] - _rot(i)) & 0xff,
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
    'safari': '18.5',
    'safariTail': '604.1',
    'appsFlyerDevKey': 'EV4eqZwVm2vYob7fghRgdF',
    'firebaseProjectNumber': '173824680995',
    'oneLinkHost': 'embercrest.onelink.me',
  };

  for (final entry in values.entries) {
    final encoded = fold(entry.value);
    print('${entry.key}: <int>[${encoded.join(', ')}]');
    if (unfold(encoded) != entry.value) {
      throw StateError('Round-trip failed for ${entry.key}');
    }
  }
  print('VERIFY: all values round-tripped');
}
