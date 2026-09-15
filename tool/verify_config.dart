import '../lib/live_ops/config/config.dart';

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
    'endpoint': LiveConfig.endpoint,
    'privacy': LiveConfig.privacyUrl,
    'support': LiveConfig.supportUrl,
    'gcd': LiveConfig.gcdBase,
    'af': LiveConfig.appsFlyerKey,
    'fb': LiveConfig.firebaseProjectNumber,
    'onelink': LiveConfig.oneLinkHost,
    'webkit': LiveConfig.webKitVersion,
    'safari': LiveConfig.safariVersion,
    'safariTail': LiveConfig.safariTail,
    'paid': LiveConfig.paidStatus,
    'uaHead': LiveConfig.uaHead,
    'uaMid1': LiveConfig.uaMid1,
    'uaMid2': LiveConfig.uaMid2,
    'uaMid3': LiveConfig.uaMid3,
    'uaApp': LiveConfig.uaApp,
    'uaName': LiveConfig.uaName,
  };
  var failed = false;
  for (final key in expected.keys) {
    if (got[key] != expected[key]) {
      failed = true;
      print('FAIL $key\n  expected: ${expected[key]}\n  got:      ${got[key]}');
    }
  }
  if (failed || !LiveConfig.pactReady) {
    throw StateError('pact decode mismatch ready=${LiveConfig.pactReady}');
  }
  print('OK pactReady=${LiveConfig.pactReady}');
}
