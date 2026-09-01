import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

class ReachProbe {
  final Connectivity _connectivity = Connectivity();

  Future<bool> hasInterface() async {
    try {
      final status = await _connectivity.checkConnectivity();
      return status.any((value) => value != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Future<bool> canReachNetwork() async {
    if (!await hasInterface()) return false;
    for (final host in const <String>['dns9.quad9.net', 'resolver1.opendns.com']) {
      try {
        final records = await InternetAddress.lookup(
          host,
        ).timeout(const Duration(seconds: 4));
        if (records.any((record) => record.rawAddress.isNotEmpty)) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}
