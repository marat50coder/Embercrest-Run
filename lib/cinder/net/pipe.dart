import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../hold/chest.dart';
import '../pact/trace.dart';

@pragma('vm:entry-point')
Future<void> cinderBgPing(RemoteMessage _) async {}

class AlertPipe {
  AlertPipe(this._locker, {required this.enabled});

  final AshChest _locker;
  final bool enabled;
  FirebaseMessaging? _messaging;
  Future<void>? _bootFuture;
  Future<bool>? _permissionFuture;
  String? _token;

  void Function(String url)? onDestination;
  void Function(String token)? onTokenChanged;

  String? get token => _token;

  Future<void> boot() => _bootFuture ??= _boot();

  Future<void> _boot() async {
    if (!enabled) return;
    final messaging = FirebaseMessaging.instance;
    _messaging = messaging;
    try {
      final initial = await messaging.getInitialMessage().timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
      final initialUrl = initial == null ? null : _extract(initial.data);
      if (initialUrl != null) await _locker.stashPushUrl(initialUrl);
    } catch (error) {
      cinderLog(() => '[CV.PING] initial message failed: $error');
    }

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    messaging.onTokenRefresh.listen((value) {
      _token = value;
      onTokenChanged?.call(value);
    });
    FirebaseMessaging.onMessage.listen(_acceptPush);
    FirebaseMessaging.onMessageOpenedApp.listen(_acceptPush);
    await _refreshToken();
  }

  void _acceptPush(RemoteMessage message) {
    final url = _extract(message.data);
    if (url == null) return;
    final callback = onDestination;
    if (callback == null) {
      _locker.stashPushUrl(url);
    } else {
      callback(url);
    }
  }

  Future<void> _refreshToken({int attempts = 6}) async {
    final messaging = _messaging;
    if (messaging == null) return;
    await _waitForApns(attempts: attempts);
    try {
      _token = await messaging.getToken();
      if (_token?.isNotEmpty ?? false) {
        onTokenChanged?.call(_token!);
      }
    } catch (error) {
      cinderLog(() => '[CV.PING] getToken failed: $error');
    }
  }

  String? _extract(Map<String, dynamic> payload) {
    for (final key in const <String>[
      'deep_link',
      'target',
      'url',
      'deeplink',
      'link',
    ]) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    for (final container in const <String>['payload', 'data']) {
      final nested = payload[container];
      if (nested is Map) {
        final found = _extract(Map<String, dynamic>.from(nested));
        if (found != null) return found;
      }
    }
    return null;
  }

  Future<void> _waitForApns({int attempts = 6}) async {
    final messaging = _messaging;
    if (messaging == null) return;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        if ((await messaging.getAPNSToken())?.isNotEmpty ?? false) return;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 550));
    }
  }

  Future<bool> canOfferPermission() async {
    if (!enabled) return false;
    try {
      await boot();
    } catch (error) {
      cinderLog(() => '[CV.PING] boot before offer failed: $error');
      return false;
    }
    final messaging = _messaging;
    if (messaging == null) return false;
    final status =
        (await messaging.getNotificationSettings()).authorizationStatus;
    if (status == AuthorizationStatus.authorized) return false;
    if (status == AuthorizationStatus.denied) return false;
    return status == AuthorizationStatus.notDetermined ||
        status == AuthorizationStatus.provisional;
  }

  Future<bool> askPermission() {
    return _permissionFuture ??= _performPermissionRequest().whenComplete(
      () => _permissionFuture = null,
    );
  }

  Future<bool> _performPermissionRequest() async {
    if (!enabled) return false;
    try {
      await boot();
    } catch (error) {
      cinderLog(() => '[CV.PING] boot before ask failed: $error');
      return false;
    }
    if (_messaging == null) return false;
    final result = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final accepted =
        result.authorizationStatus == AuthorizationStatus.authorized ||
        result.authorizationStatus == AuthorizationStatus.provisional;
    await _locker.setPingAllowed(accepted);
    if (!accepted && result.authorizationStatus == AuthorizationStatus.denied) {
      await _locker.markPingBlockedByOs();
    }
    if (accepted) {
      await _refreshToken(attempts: 14);
    }
    return accepted;
  }
}
