import '../lib/cinder/pact/pact.dart';

void main() {
  final expected = <String, String>{
    'endpoint': 'https://embercrestrun.com/config.php',
    'privacy': 'https://embercrestrun.com/privacy-policy.html',
    'support': 'https://embercrestrun.com/support.html',
    'gcd': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
    'af': 'EV4eqZwVm2vYob7fghRgdF',
    'fb': '173824680995',
    'onelink': 'embercrest.onelink.me',
    'webkit': '605.1.15',
    'safari': '18.4',
    'safariTail': '604.1',
    'paid': 'Non-organic',
    'uaHead': 'Mozilla/5.0 (iPhone; CPU iPhone OS ',
    'uaMid1': ' like Mac OS X) AppleWebKit/',
    'uaMid2': ' (KHTML, like Gecko) Version/',
    'uaMid3': ' Mobile/15E148 Safari/',
    'uaApp': ' appid/',
    'uaName': ' appname/',
  };
  final got = <String, String>{
    'endpoint': CinderPact.endpoint,
    'privacy': CinderPact.privacyUrl,
    'support': CinderPact.supportUrl,
    'gcd': CinderPact.gcdBase,
    'af': CinderPact.appsFlyerKey,
    'fb': CinderPact.firebaseProjectNumber,
    'onelink': CinderPact.oneLinkHost,
    'webkit': CinderPact.webKitVersion,
    'safari': CinderPact.safariVersion,
    'safariTail': CinderPact.safariTail,
    'paid': CinderPact.paidStatus,
    'uaHead': CinderPact.uaHead,
    'uaMid1': CinderPact.uaMid1,
    'uaMid2': CinderPact.uaMid2,
    'uaMid3': CinderPact.uaMid3,
    'uaApp': CinderPact.uaApp,
    'uaName': CinderPact.uaName,
  };
  var failed = false;
  for (final key in expected.keys) {
    if (got[key] != expected[key]) {
      failed = true;
      print('FAIL $key\n  expected: ${expected[key]}\n  got:      ${got[key]}');
    }
  }
  if (failed || !CinderPact.pactReady) {
    throw StateError('pact decode mismatch ready=${CinderPact.pactReady}');
  }
  print('OK pactReady=${CinderPact.pactReady}');
}
