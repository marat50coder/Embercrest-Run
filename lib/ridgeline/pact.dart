import 'codec.dart';

/// Runtime secrets and store identity for the attribution → config path.
abstract final class RidgePact {
  static const String appTitle = 'Embercrest Run';
  static const String appName = 'EmbercrestRun';
  static const String bundleId = 'com.embercrest.rungame';
  static const String iosStoreId = '6792816894';

  static const int noticeSnoozeSeconds = 259200; // 3 days
  static const int organicReplaySeconds = 8;

  /// Debug-only: inject Non-organic status so the in-app browser can be tested.
  ///   flutter run --dart-define=FORCE_RIFT=true
  static const bool debugForceRift =
      bool.fromEnvironment('FORCE_RIFT', defaultValue: false);

  static const List<int> _endpoint = <int>[
    162, 210, 80, 181, 46, 46, 78, 134, 175, 114, 109, 0, 152, 45, 22, 78,
    214, 187, 22, 34, 217, 87, 217, 251, 120, 254, 237, 161, 150, 213, 223,
    17, 59, 168, 250, 98,
  ];
  static const List<int> _privacy = <int>[
    162, 210, 80, 181, 46, 46, 78, 134, 175, 114, 109, 0, 152, 45, 22, 78,
    214, 187, 22, 34, 217, 87, 217, 251, 120, 254, 254, 188, 145, 197, 215,
    21, 108, 245, 226, 125, 46, 118, 28, 204, 36, 111, 53, 236, 236,
  ];
  static const List<int> _support = <int>[
    162, 210, 80, 181, 46, 46, 78, 134, 175, 114, 109, 0, 152, 45, 22, 78,
    214, 187, 22, 34, 217, 87, 217, 251, 120, 254, 253, 187, 136, 195, 217,
    4, 97, 246, 250, 102, 47, 115,
  ];
  static const List<int> _gcd = <int>[
    162, 210, 80, 181, 46, 46, 78, 134, 173, 124, 107, 22, 142, 37, 74, 74,
    213, 191, 23, 49, 219, 0, 223, 230, 59, 178, 225, 163, 215, 218, 216, 5,
    97, 185, 254, 126, 29, 123, 30, 193, 107, 40, 55, 180, 174, 56, 225,
  ];
  static const List<int> _appsFlyerKey = <int>[
    143, 240, 16, 160, 44, 78, 22, 255, 167, 45, 121, 60, 133, 44, 83, 77,
    194, 167, 54, 48, 211, 63,
  ];
  static const List<int> _firebaseProject = <int>[
    251, 145, 23, 253, 111, 32, 87, 145, 250, 38, 54, 80,
  ];
  static const List<int> _webkit = <int>[252, 150, 17, 235, 108, 58, 80, 156];
  static const List<int> _safari = <int>[251, 158, 10, 243];
  static const List<int> _safariTail = <int>[252, 150, 17, 235, 108];
  static const List<int> _oneLinkHost = <int>[
    175, 203, 70, 160, 47, 119, 19, 204, 185, 107, 33, 10, 132, 43, 8, 66,
    203, 164, 74, 58, 210,
  ];

  static String get endpoint => unsealRift(_endpoint);
  static String get privacyUrl => unsealRift(_privacy);
  static String get supportUrl => unsealRift(_support);
  static String get gcdBase => unsealRift(_gcd);
  static String get webKitVersion => unsealRift(_webkit);
  static String get safariVersion => unsealRift(_safari);
  static String get safariTail => unsealRift(_safariTail);
  static String get appsFlyerKey => unsealRift(_appsFlyerKey);
  static String get firebaseProjectNumber => unsealRift(_firebaseProject);
  static String get oneLinkHost => unsealRift(_oneLinkHost);

  static String get storeToken => 'id$iosStoreId';

  static bool get pactReady =>
      endpoint.isNotEmpty &&
      appsFlyerKey.isNotEmpty &&
      firebaseProjectNumber.isNotEmpty;
}
