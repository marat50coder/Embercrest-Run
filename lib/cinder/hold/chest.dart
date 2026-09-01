import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../trail/call.dart';

class AshChest {
  static const String _pathKey = 'qxk_m.path';
  static const String _expiryKey = 'qxk_m.until';
  static const String _inviteKey = 'qxk_m.card.after';
  static const String _permissionKey = 'qxk_m.alert.ok';
  static const String _osDeniedKey = 'qxk_m.alert.block';
  static const String _savedUrlKey = 'qxk_m.safe.target';
  static const String _pendingUrlKey = 'qxk_m.safe.queue';

  final FlutterSecureStorage _safe = const FlutterSecureStorage();
  late SharedPreferences _prefs;

  Future<void> open() async {
    _prefs = await SharedPreferences.getInstance();
  }

  AshPath get path => AshPath.parse(_prefs.getString(_pathKey));

  Future<void> savePath(AshPath path) =>
      _prefs.setString(_pathKey, path.lockerToken);

  Future<String?> savedUrl() async {
    try {
      return await _safe.read(key: _savedUrlKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheUrl(String url, int? expiresAt) async {
    try {
      await _safe.write(key: _savedUrlKey, value: url);
      if (expiresAt != null) {
        await _prefs.setInt(_expiryKey, expiresAt);
      }
    } catch (_) {}
  }

  bool get cachedUrlExpired {
    final expiry = _prefs.getInt(_expiryKey);
    return expiry == null ||
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= expiry;
  }

  Future<void> stashPushUrl(String url) async {
    if (url.trim().isEmpty) return;
    try {
      await _safe.write(key: _pendingUrlKey, value: url.trim());
    } catch (_) {}
  }

  Future<String?> consumePushUrl() async {
    try {
      final value = await _safe.read(key: _pendingUrlKey);
      if (value != null) await _safe.delete(key: _pendingUrlKey);
      return value;
    } catch (_) {
      return null;
    }
  }

  bool get pingAllowed => _prefs.getBool(_permissionKey) ?? false;
  bool get pingBlockedByOs => _prefs.getBool(_osDeniedKey) ?? false;

  Future<void> setPingAllowed(bool value) =>
      _prefs.setBool(_permissionKey, value);

  Future<void> markPingBlockedByOs() => _prefs.setBool(_osDeniedKey, true);

  bool get shouldOfferNotice {
    if (pingAllowed) return false;
    final after = _prefs.getInt(_inviteKey);
    return after == null ||
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= after;
  }

  Future<void> snoozeNotice(int epochSeconds) =>
      _prefs.setInt(_inviteKey, epochSeconds);
}
