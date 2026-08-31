import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import 'pact.dart';

/// HTTP client that presents a Mobile Safari UA (also reused by the in-app browser).
class SafariMask extends http.BaseClient {
  final http.Client _inner = http.Client();
  String? _agent;

  Future<void> warm() async {
    try {
      if (!Platform.isIOS) {
        _agent = _fallback();
        return;
      }
      final info = await DeviceInfoPlugin().iosInfo;
      _agent = _safari(_normalizedIos(info.systemVersion));
    } catch (_) {
      _agent = _fallback();
    }
  }

  String get userAgent => _agent ?? _fallback();

  String _normalizedIos(String raw) {
    final parts = raw
        .split('.')
        .map(int.tryParse)
        .whereType<int>()
        .take(3)
        .toList();
    if (parts.isEmpty || parts.first < 18) return '18.6';
    return parts.join('.');
  }

  String _safari(String iosVersion) {
    final cpu = iosVersion.replaceAll('.', '_');
    return 'Mozilla/5.0 (iPhone; CPU iPhone OS $cpu like Mac OS X) '
        'AppleWebKit/${RidgePact.webKitVersion} (KHTML, like Gecko) '
        'Version/${RidgePact.safariVersion} Mobile/15E148 '
        'Safari/${RidgePact.safariTail} '
        'appid/${RidgePact.iosStoreId} appname/${RidgePact.appName}';
  }

  String _fallback() => _safari('18.6');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
