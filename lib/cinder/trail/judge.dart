import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../net/book.dart';
import '../hold/chest.dart';
import '../net/face.dart';
import '../pact/trace.dart';
import '../pact/pact.dart';
import '../net/pipe.dart';
import '../net/probe.dart';
import 'call.dart';
import '../hold/href.dart';
import '../net/post.dart';

class PathJudge {
  PathJudge({
    required this.locker,
    required this.pulse,
    required this.ledger,
    required this.wire,
    required this.ping,
    required this.mask,
    required this.runtimeEnabled,
  });

  final AshChest locker;
  final ReachProbe pulse;
  final SignalBook ledger;
  final PactPost wire;
  final AlertPipe ping;
  final AgentFace mask;
  final bool runtimeEnabled;

  bool get enabled => runtimeEnabled && CinderPact.pactReady;

  Future<PathCall>? _decideFuture;

  Future<PathCall> decide({
    required void Function(double value) onProgress,
  }) =>
      _decideFuture ??= _decide(onProgress: onProgress)
          .whenComplete(() => _decideFuture = null);

  Future<PathCall> _decide({
    required void Function(double value) onProgress,
  }) async {
    if (!enabled) {
      cinderLog(
        () => '[BR.ARB] disabled runtime=$runtimeEnabled '
            'pact=${CinderPact.pactReady}',
      );
      onProgress(1);
      return const PlayCall();
    }

    cinderLog(() => '[BR.ARB] decide start path=${locker.path}');

    ping.onTokenChanged = _refreshForToken;
    try {
      await ping.boot();
    } catch (_) {}
    final coldRoute = await ColdHref.consume();
    if (coldRoute != null) {
      await locker.savePath(AshPath.view);
      await locker.consumePushUrl();
      unawaited(_backgroundDispatch());
      onProgress(1);
      return ViewCall(coldRoute, coldLaunch: true);
    }

    onProgress(0.14);
    return switch (locker.path) {
      AshPath.idle => _firstDecision(onProgress),
      AshPath.view => _returningView(onProgress),
      AshPath.play => _returningPlay(onProgress),
    };
  }

  Future<PathCall> _firstDecision(void Function(double) progress) async {
    if (!await pulse.hasInterface()) {
      cinderLog(() => '[BR.ARB] first: no interface → gloom');
      return const QuietCall(returnToPlay: false);
    }
    progress(0.30);
    try {
      await ping.boot();
    } catch (_) {}
    if (!await pulse.canReachNetwork()) {
      cinderLog(() => '[BR.ARB] first: probe failed → gloom');
      return const QuietCall(returnToPlay: false);
    }
    progress(0.50);
    await ledger.awaitSignals();
    progress(0.74);
    final reply = await _requestConfig();
    progress(1);
    cinderLog(
      () => '[BR.ARB] first: hasDest=${reply.hasDestination} url=${reply.url}',
    );
    if (reply.hasDestination) {
      await locker.savePath(AshPath.view);
      return ViewCall(reply.url!);
    }
    await locker.savePath(AshPath.play);
    return const PlayCall();
  }

  Future<PathCall> _returningView(void Function(double) progress) async {
    if (!await pulse.hasInterface()) {
      return const QuietCall(returnToPlay: false);
    }
    final pending = await locker.consumePushUrl();
    if (pending != null && pending.isNotEmpty) {
      progress(1);
      return ViewCall(pending);
    }
    final cached = await locker.savedUrl();
    if (cached != null && !locker.cachedUrlExpired) {
      progress(1);
      return ViewCall(cached);
    }

    await Future.wait<void>(<Future<void>>[
      ping.boot(),
      ledger.start(),
    ]);
    if (!await pulse.canReachNetwork()) {
      return const QuietCall(returnToPlay: false);
    }
    progress(0.64);
    await ledger.awaitSignals(installTimeout: const Duration(seconds: 6));
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) return ViewCall(reply.url!);
    if (cached != null) return ViewCall(cached);
    return const QuietCall(returnToPlay: false);
  }

  Future<PathCall> _returningPlay(void Function(double) progress) async {
    if (!await pulse.hasInterface()) {
      progress(1);
      return const PlayCall();
    }
    await Future.wait<void>(<Future<void>>[
      ping.boot(),
      ledger.start(),
    ]);
    if (!await pulse.canReachNetwork()) {
      progress(1);
      return const PlayCall();
    }
    progress(0.58);
    await ledger.awaitSignals();
    final reply = await _requestConfig();
    progress(1);
    if (!reply.hasDestination) return const PlayCall();
    await locker.savePath(AshPath.view);
    return ViewCall(reply.url!);
  }

  Future<PactNote> _requestConfig({String? token}) async {
    final body = await ledger.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? ping.token,
    );
    if (kDebugMode && CinderPact.debugKeepSheet) {
      body['af_status'] = CinderPact.paidStatus;
      cinderLog(() => '[BR.ARB] debug force view');
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
