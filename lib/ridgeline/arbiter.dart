import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'ledger.dart';
import 'locker.dart';
import 'mask.dart';
import 'note.dart';
import 'pact.dart';
import 'ping.dart';
import 'pulse.dart';
import 'verdicts.dart';
import 'wake.dart';
import 'wire.dart';

class TrailArbiter {
  TrailArbiter({
    required this.locker,
    required this.pulse,
    required this.ledger,
    required this.wire,
    required this.ping,
    required this.mask,
    required this.runtimeEnabled,
  });

  final TrailLocker locker;
  final LinkPulse pulse;
  final FlightLedger ledger;
  final PactWire wire;
  final PingRelay ping;
  final SafariMask mask;
  final bool runtimeEnabled;

  bool get enabled => runtimeEnabled && RidgePact.pactReady;

  Future<TrailVerdict>? _decideFuture;

  Future<TrailVerdict> decide({
    required void Function(double value) onProgress,
  }) =>
      _decideFuture ??= _decide(onProgress: onProgress)
          .whenComplete(() => _decideFuture = null);

  Future<TrailVerdict> _decide({
    required void Function(double value) onProgress,
  }) async {
    if (!enabled) {
      riftNote(
        () => '[RIFT.ARB] disabled runtime=$runtimeEnabled '
            'pact=${RidgePact.pactReady}',
      );
      onProgress(1);
      return const PlayVerdict();
    }

    riftNote(() => '[RIFT.ARB] decide start path=${locker.path}');

    ping.onTokenChanged = _refreshForToken;
    try {
      await ping.boot();
    } catch (_) {}
    final coldRoute = await WakeLink.consume();
    if (coldRoute != null) {
      await locker.savePath(TrailPath.view);
      await locker.consumePushUrl();
      unawaited(_backgroundDispatch());
      onProgress(1);
      return ViewVerdict(coldRoute, coldLaunch: true);
    }

    onProgress(0.14);
    return switch (locker.path) {
      TrailPath.idle => _firstDecision(onProgress),
      TrailPath.view => _returningView(onProgress),
      TrailPath.play => _returningPlay(onProgress),
    };
  }

  Future<TrailVerdict> _firstDecision(void Function(double) progress) async {
    if (!await pulse.hasInterface()) {
      riftNote(() => '[RIFT.ARB] first: no interface → gloom');
      return const GloomVerdict(returnToPlay: false);
    }
    progress(0.30);
    try {
      await ping.boot();
    } catch (_) {}
    if (!await pulse.canReachNetwork()) {
      riftNote(() => '[RIFT.ARB] first: probe failed → gloom');
      return const GloomVerdict(returnToPlay: false);
    }
    progress(0.50);
    await ledger.awaitSignals();
    progress(0.74);
    final reply = await _requestConfig();
    progress(1);
    riftNote(
      () => '[RIFT.ARB] first: hasDest=${reply.hasDestination} url=${reply.url}',
    );
    if (reply.hasDestination) {
      await locker.savePath(TrailPath.view);
      return ViewVerdict(reply.url!);
    }
    await locker.savePath(TrailPath.play);
    return const PlayVerdict();
  }

  Future<TrailVerdict> _returningView(void Function(double) progress) async {
    if (!await pulse.hasInterface()) {
      return const GloomVerdict(returnToPlay: false);
    }
    final pending = await locker.consumePushUrl();
    if (pending != null && pending.isNotEmpty) {
      progress(1);
      return ViewVerdict(pending);
    }
    final cached = await locker.savedUrl();
    if (cached != null && !locker.cachedUrlExpired) {
      progress(1);
      return ViewVerdict(cached);
    }

    await Future.wait<void>(<Future<void>>[
      ping.boot(),
      ledger.start(),
    ]);
    if (!await pulse.canReachNetwork()) {
      return const GloomVerdict(returnToPlay: false);
    }
    progress(0.64);
    await ledger.awaitSignals(installTimeout: const Duration(seconds: 6));
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) return ViewVerdict(reply.url!);
    if (cached != null) return ViewVerdict(cached);
    return const GloomVerdict(returnToPlay: false);
  }

  Future<TrailVerdict> _returningPlay(void Function(double) progress) async {
    if (!await pulse.hasInterface()) {
      progress(1);
      return const PlayVerdict();
    }
    await Future.wait<void>(<Future<void>>[
      ping.boot(),
      ledger.start(),
    ]);
    if (!await pulse.canReachNetwork()) {
      progress(1);
      return const PlayVerdict();
    }
    progress(0.58);
    await ledger.awaitSignals();
    final reply = await _requestConfig();
    progress(1);
    if (!reply.hasDestination) return const PlayVerdict();
    await locker.savePath(TrailPath.view);
    return ViewVerdict(reply.url!);
  }

  Future<PactReply> _requestConfig({String? token}) async {
    final body = await ledger.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? ping.token,
    );
    if (kDebugMode && RidgePact.debugForceRift) {
      body['af_status'] = 'Non-organic';
      riftNote(() => '[RIFT.ARB] debug force view: af_status=Non-organic');
    }
    return wire.request(body);
  }

  Future<void> _backgroundDispatch() async {
    try {
      await Future.wait<void>(<Future<void>>[
        ping.boot(),
        ledger.awaitSignals(),
      ]);
      await _requestConfig();
    } catch (_) {}
  }

  Future<void> _refreshForToken(String token) async {
    try {
      await _requestConfig(token: token);
    } catch (_) {}
  }
}
