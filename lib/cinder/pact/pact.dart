import 'seal.dart';

abstract final class CinderPact {
  static const String appTitle = 'Embercrest Run';
  static const String appName = 'EmbercrestRun';
  static const String bundleId = 'com.embercrest.rungame';
  static const String iosStoreId = '6792816894';

  static const int noticeSnoozeSeconds = 259200;
  static const int organicReplaySeconds = 11;

  static const bool debugKeepSheet =
      bool.fromEnvironment('KEEP_SHEET', defaultValue: false);

  static const List<int> _endpoint = <int>[
    84, 123, 178, 245, 129, 239, 237, 242, 168, 83, 5, 247, 99, 98, 113, 6,
    30, 107, 153, 135, 17, 19, 124, 18, 198, 15, 248, 49, 99, 156, 134, 116,
    53, 62, 191, 81,
  ];
  static const List<int> _privacy = <int>[
    84, 123, 178, 245, 129, 239, 237, 242, 168, 83, 5, 247, 99, 98, 113, 6,
    30, 107, 153, 135, 17, 19, 124, 18, 198, 15, 235, 44, 100, 140, 142, 112,
    98, 99, 167, 78, 228, 163, 9, 163, 66, 104, 194, 91, 181,
  ];
  static const List<int> _support = <int>[
    84, 123, 178, 245, 129, 239, 237, 242, 168, 83, 5, 247, 99, 98, 113, 6,
    30, 107, 153, 135, 17, 19, 124, 18, 198, 15, 232, 43, 125, 138, 128, 97,
    111, 96, 191, 85, 229, 166,
  ];
  static const List<int> _gcd = <int>[
    84, 123, 178, 245, 129, 239, 237, 242, 170, 93, 3, 225, 117, 106, 45, 2,
    29, 111, 152, 148, 19, 68, 122, 15, 133, 67, 244, 51, 34, 147, 129, 96,
    111, 47, 187, 77, 215, 174, 11, 174, 13, 47, 192, 3, 247, 30, 242,
  ];
  static const List<int> _appsFlyerKey = <int>[
    121, 89, 242, 224, 131, 143, 181, 139, 160, 12, 17, 203, 126, 99, 52, 5,
    10, 119, 185, 149, 27, 123,
  ];
  static const List<int> _firebaseProject = <int>[
    13, 56, 245, 189, 192, 225, 244, 229, 253, 7, 94, 167,
  ];
  static const List<int> _webkit = <int>[10, 63, 243, 171, 195, 251, 243, 232];
  static const List<int> _safari = <int>[13, 55, 232, 177];
  static const List<int> _safariTail = <int>[10, 63, 242, 171, 195];
  static const List<int> _oneLinkHost = <int>[
    89, 98, 164, 224, 128, 182, 176, 184, 190, 74, 73, 253, 127, 100, 111, 10,
    3, 116, 197, 159, 26,
  ];
  static const List<int> _uaHead = <int>[
    113, 96, 188, 236, 158, 185, 163, 242, 248, 16, 87, 178, 57, 104, 83, 11,
    2, 113, 142, 201, 95, 126, 79, 40, 139, 73, 203, 54, 98, 148, 138, 51, 84,
    29, 247,
  ];
  static const List<int> _uaMid1 = <int>[
    28, 99, 175, 238, 151, 245, 143, 188, 174, 30, 40, 193, 49, 89, 42, 67,
    44, 111, 155, 158, 26, 106, 122, 31, 224, 73, 239, 113,
  ];
  static const List<int> _uaMid2 = <int>[
    28, 39, 141, 205, 166, 152, 142, 241, 237, 82, 14, 249, 116, 33, 68, 6,
    14, 116, 132, 219, 95, 107, 122, 15, 216, 73, 244, 48, 34,
  ];
  static const List<int> _uaMid3 = <int>[
    28, 66, 169, 231, 155, 185, 167, 242, 252, 11, 34, 163, 37, 57, 35, 48,
    12, 121, 138, 128, 22, 18,
  ];
  static const List<int> _uaApp = <int>[28, 110, 182, 245, 155, 177, 237];
  static const List<int> _uaName = <int>[
    28, 110, 182, 245, 156, 180, 175, 184, 226,
  ];
  static const List<int> _paidStatus = <int>[
    114, 96, 168, 168, 157, 167, 165, 188, 163, 87, 4,
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
