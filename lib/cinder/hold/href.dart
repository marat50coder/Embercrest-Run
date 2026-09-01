import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads the killed-state notification destination written by SceneDelegate
/// into UserDefaults (`flutter.cv_wake_href`).
class ColdHref {
  static const String dartKey = 'cv_wake_href';

  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(dartKey)?.trim();
      if (value == null || value.isEmpty) return null;
      await preferences.remove(dartKey);
      return value;
    } catch (_) {
      return null;
    }
  }
}
