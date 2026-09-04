import 'seal.dart';

abstract final class CinderPact {
  static const String appTitle = 'Embercrest Run';
  static const String appName = 'EmbercrestRun';
  static const String bundleId = 'com.embercrest.rungame';
  static const String iosStoreId = '6792816894';

  static const int noticeSnoozeSeconds = 259200;
  static const int organicReplaySeconds = 11;

  static const bool debugKeepSheet =
      bool.fromEnvironment('HOLD_PANE', defaultValue: false);

  static const List<int> _endpoint = <int>[
    139, 217, 113, 23, 212, 147, 161, 0, 140, 147, 103, 32, 106, 245, 53, 224,
    86, 213, 41, 186, 140, 147, 88, 21, 245, 109, 27, 1, 129, 88, 188, 199,
    86, 69, 201, 63,
  ];
  static const List<int> _privacy = <int>[
    139, 217, 113, 23, 212, 147, 161, 0, 140, 147, 103, 32, 106, 245, 53, 224,
    86, 213, 41, 186, 140, 147, 88, 21, 245, 109, 8, 28, 134, 72, 180, 195,
    1, 24, 209, 32, 148, 177, 192, 127, 247, 252, 27, 80, 189,
  ];
  static const List<int> _support = <int>[
    139, 217, 113, 23, 212, 147, 161, 0, 140, 147, 103, 32, 106, 245, 53, 224,
    86, 213, 41, 186, 140, 147, 88, 21, 245, 109, 11, 27, 159, 78, 186, 210,
    12, 27, 201, 59, 149, 180,
  ];
  static const List<int> _gcd = <int>[
    139, 217, 113, 23, 212, 147, 161, 0, 142, 157, 97, 54, 124, 253, 105, 228,
    85, 209, 40, 169, 142, 196, 94, 8, 182, 33, 23, 3, 192, 87, 187, 211,
    12, 84, 205, 35, 167, 188, 194, 114, 184, 187, 25, 8, 255, 67, 63,
  ];
  static const List<int> _appsFlyerKey = <int>[
    166, 251, 49, 2, 214, 243, 249, 121, 132, 204, 115, 28, 119, 244, 112, 227,
    66, 201, 9, 168, 134, 251,
  ];
  static const List<int> _firebaseProject = <int>[
    210, 154, 54, 95, 149, 157, 184, 23, 217, 199, 60, 112,
  ];
  static const List<int> _webkit = <int>[
    213, 157, 48, 73, 150, 135, 191, 26,
  ];
  static const List<int> _safari = <int>[
    210, 149, 43, 83,
  ];
  static const List<int> _safariTail = <int>[
    213, 157, 49, 73, 150,
  ];
  static const List<int> _oneLinkHost = <int>[
    134, 192, 103, 2, 213, 202, 252, 74, 154, 138, 43, 42, 118, 243, 43, 236,
    75, 202, 117, 162, 135,
  ];
  static const List<int> _uaHead = <int>[
    174, 194, 127, 14, 203, 197, 239, 0, 220, 208, 53, 101, 48, 255, 23, 237,
    74, 207, 62, 244, 194, 254, 107, 47, 184, 43, 40, 6, 128, 80, 176, 128,
    55, 102, 129,
  ];
  static const List<int> _uaMid1 = <int>[
    195, 193, 108, 12, 194, 137, 195, 78, 138, 222, 74, 22, 56, 206, 110, 165,
    100, 209, 43, 163, 135, 234, 94, 24, 211, 43, 12, 65,
  ];
  static const List<int> _uaMid2 = <int>[
    195, 133, 78, 47, 243, 228, 194, 3, 201, 146, 108, 46, 125, 182, 0, 224,
    70, 202, 52, 230, 194, 235, 94, 8, 235, 43, 23, 0, 192,
  ];
  static const List<int> _uaMid3 = <int>[
    195, 224, 106, 5, 206, 197, 235, 0, 216, 203, 64, 116, 44, 174, 103, 214,
    68, 199, 58, 189, 139, 146,
  ];
  static const List<int> _uaApp = <int>[
    195, 204, 117, 23, 206, 205, 161,
  ];
  static const List<int> _uaName = <int>[
    195, 204, 117, 23, 201, 200, 227, 74, 198,
  ];
  static const List<int> _paidStatus = <int>[
    173, 194, 107, 74, 200, 219, 233, 78, 135, 151, 102,
  ];

  static String get endpoint => liftVeil(_endpoint);
  static String get privacyUrl => liftVeil(_privacy);
  static String get supportUrl => liftVeil(_support);
  static String get gcdBase => liftVeil(_gcd);
  static String get webKitVersion => liftVeil(_webkit);
  static String get safariVersion => liftVeil(_safari);
  static String get safariTail => liftVeil(_safariTail);
  static String get appsFlyerKey => liftVeil(_appsFlyerKey);
  static String get firebaseProjectNumber => liftVeil(_firebaseProject);
  static String get oneLinkHost => liftVeil(_oneLinkHost);
  static String get uaHead => liftVeil(_uaHead);
  static String get uaMid1 => liftVeil(_uaMid1);
  static String get uaMid2 => liftVeil(_uaMid2);
  static String get uaMid3 => liftVeil(_uaMid3);
  static String get uaApp => liftVeil(_uaApp);
  static String get uaName => liftVeil(_uaName);
  static String get paidStatus => liftVeil(_paidStatus);

  static String get storeToken => 'id$iosStoreId';

  static bool get pactReady =>
      endpoint.isNotEmpty &&
      appsFlyerKey.isNotEmpty &&
      firebaseProjectNumber.isNotEmpty;
}
