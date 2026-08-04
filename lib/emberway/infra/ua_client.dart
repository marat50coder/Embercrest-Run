import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/ember_gate_config.dart';

/// HTTP client that forges a real Mobile Safari User-Agent (also reused by the
/// WebView). Never leaks Dart/Flutter/CFNetwork/Darwin tokens.
class UaClient extends http.BaseClient {
  final http.Client _transport = http.Client();
  String? _userAgent;

  Future<void> prepare() async {
    try {
      if (!Platform.isIOS) {
        _userAgent = _fallback();
        return;
      }
      final info = await DeviceInfoPlugin().iosInfo;
      _userAgent = _mobileSafari(_normalizedIos(info.systemVersion));
    } catch (_) {
      _userAgent = _fallback();
    }
  }

  String get userAgent => _userAgent ?? _fallback();

  String _normalizedIos(String raw) {
    final parts = raw
        .split('.')
        .map(int.tryParse)
        .whereType<int>()
        .take(3)
        .toList();
    if (parts.isEmpty || parts.first < 18) return '18.5';
    return parts.join('.');
  }

  // GAME THEME CATEGORY: slot → append appid/appname suffix (required).
  String _mobileSafari(String iosVersion) {
    final cpu = iosVersion.replaceAll('.', '_');
    return 'Mozilla/5.0 (iPhone; CPU iPhone OS $cpu like Mac OS X) '
        'AppleWebKit/${EmberGateConfig.webKitVersion} (KHTML, like Gecko) '
        'Version/${EmberGateConfig.safariVersion} Mobile/15E148 '
        'Safari/${EmberGateConfig.safariTail} '
        'appid/${EmberGateConfig.bundleId} appname/${EmberGateConfig.appName}';
  }

  String _fallback() => _mobileSafari('18.5');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _transport.send(request);
  }

  @override
  void close() => _transport.close();
}
