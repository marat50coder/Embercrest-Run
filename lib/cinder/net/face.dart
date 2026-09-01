import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../pact/pact.dart';

class AgentFace extends http.BaseClient {
  final http.Client _inner = http.Client();
  String? _agent;

  Future<void> warm() async {
    try {
      if (!Platform.isIOS) {
        _agent = _fallback();
        return;
      }
      final info = await DeviceInfoPlugin().iosInfo;
      _agent = _compose(_normalizedIos(info.systemVersion));
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
    if (parts.isEmpty || parts.first < 18) return '18.4';
    return parts.join('.');
  }

  String _compose(String iosVersion) {
    final cpu = iosVersion.replaceAll('.', '_');
    return '${CinderPact.uaHead}$cpu${CinderPact.uaMid1}'
        '${CinderPact.webKitVersion}${CinderPact.uaMid2}'
        '${CinderPact.safariVersion}${CinderPact.uaMid3}'
        '${CinderPact.safariTail}${CinderPact.uaApp}'
        '${CinderPact.iosStoreId}${CinderPact.uaName}'
        '${CinderPact.appName}';
  }

  String _fallback() => _compose('18.4');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
