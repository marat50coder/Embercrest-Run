import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads the cold-start push destination that SceneDelegate wrote to
/// UserDefaults (key `flutter.emb_tap_route`) when the app was launched from a
/// killed state by tapping a notification. Consumed FIRST in the boot pipeline.
class ColdTapReader {
  static const String _dartKey = 'emb_tap_route';

  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(_dartKey)?.trim();
      if (value == null || value.isEmpty) return null;
      await preferences.remove(_dartKey);
      return value;
    } catch (_) {
      return null;
    }
  }
}
