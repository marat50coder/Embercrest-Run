import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'config/ember_gate_config.dart';
import 'core/ember_log.dart';
import 'core/gate_models.dart';
import 'infra/cold_tap.dart';
import 'infra/crest_vault.dart';
import 'infra/ember_attribution.dart';
import 'infra/gate_exchange.dart';
import 'infra/net_watch.dart';
import 'infra/push_hub.dart';
import 'infra/ua_client.dart';

/// Runs the attribution → config pipeline and decides game vs WebView vs
/// offline. Routing decision maps: [CrestRoute] persisted state + the reply.
class CrestCoordinator {
  CrestCoordinator({
    required this.vault,
    required this.watch,
    required this.attribution,
    required this.exchange,
    required this.push,
    required this.agent,
    required this.runtimeEnabled,
  });

  final CrestVault vault;
  final NetWatch watch;
  final EmberAttribution attribution;
  final GateExchange exchange;
  final PushHub push;
  final UaClient agent;
  final bool runtimeEnabled;

  bool get enabled => runtimeEnabled && EmberGateConfig.grayCredentialsReady;

  Future<CrestOutcome>? _decideFuture;

  /// De-duplicates only *concurrent* startup calls, then clears the cache so a
  /// later Retry re-runs the whole pipeline instead of replaying a stale
  /// DarkOutcome.
  Future<CrestOutcome> decide({
    required void Function(double value) onProgress,
  }) =>
      _decideFuture ??= _decide(onProgress: onProgress)
          .whenComplete(() => _decideFuture = null);

  Future<CrestOutcome> _decide({
    required void Function(double value) onProgress,
  }) async {
    if (!enabled) {
      embTrace(
        () => '[EMB.CREST] gate disabled runtime=$runtimeEnabled '
            'creds=${EmberGateConfig.grayCredentialsReady}',
      );
      onProgress(1);
      return const GameOutcome();
    }

    embTrace(() => '[EMB.CREST] decide start route=${vault.route}');

    push.onTokenChanged = _refreshForToken;
    // Cold-start push tap is consumed FIRST — before network / attribution —
    // or the URL is lost to a timeout race.
    final coldRoute = await ColdTapReader.consume();
    if (coldRoute != null) {
      await vault.saveRoute(CrestRoute.web);
      await vault.consumePushUrl();
      unawaited(_backgroundDispatch());
      onProgress(1);
      return WebOutcome(coldRoute, coldLaunch: true);
    }

    onProgress(0.12);
    return switch (vault.route) {
      CrestRoute.unset => _firstDecision(onProgress),
      CrestRoute.web => _returningWeb(onProgress),
      CrestRoute.game => _returningGame(onProgress),
    };
  }

  Future<CrestOutcome> _firstDecision(void Function(double) progress) async {
    if (!await watch.hasInterface()) {
      embTrace(() => '[EMB.CREST] first: no interface → offline');
      return const DarkOutcome(returnToGame: false);
    }
    progress(0.28);
    try {
      await push.boot();
    } catch (_) {}
    if (!await watch.canReachNetwork()) {
      embTrace(() => '[EMB.CREST] first: DNS probe failed → offline');
      return const DarkOutcome(returnToGame: false);
    }
    progress(0.48);
    await attribution.awaitSignals();
    progress(0.72);
    final reply = await _requestConfig();
    progress(1);
    embTrace(
      () => '[EMB.CREST] first: hasDest=${reply.hasDestination} url=${reply.url}',
    );
    if (reply.hasDestination) {
      await vault.saveRoute(CrestRoute.web);
      return WebOutcome(reply.url!);
    }
    // Only a successful reply with no URL commits the game path.
    await vault.saveRoute(CrestRoute.game);
    return const GameOutcome();
  }

  Future<CrestOutcome> _returningWeb(void Function(double) progress) async {
    if (!await watch.hasInterface()) {
      return const DarkOutcome(returnToGame: false);
    }
    final pending = await vault.consumePushUrl();
    if (pending != null && pending.isNotEmpty) {
      progress(1);
      return WebOutcome(pending);
    }
    final cached = await vault.savedUrl();
    if (cached != null && !vault.cachedUrlExpired) {
      progress(1);
      return WebOutcome(cached);
    }

    await Future.wait<void>(<Future<void>>[
      push.boot(),
      attribution.start(),
    ]);
    if (!await watch.canReachNetwork()) {
      return const DarkOutcome(returnToGame: false);
    }
    progress(0.62);
    await attribution.awaitSignals(installTimeout: const Duration(seconds: 5));
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) return WebOutcome(reply.url!);
    if (cached != null) return WebOutcome(cached);
    return const DarkOutcome(returnToGame: false);
  }

  Future<CrestOutcome> _returningGame(void Function(double) progress) async {
    if (!await watch.hasInterface()) {
      progress(1);
      return const GameOutcome();
    }
    await Future.wait<void>(<Future<void>>[
      push.boot(),
      attribution.start(),
    ]);
    if (!await watch.canReachNetwork()) {
      progress(1);
      return const GameOutcome();
    }
    progress(0.55);
    await attribution.awaitSignals();
    final reply = await _requestConfig();
    progress(1);
    if (!reply.hasDestination) return const GameOutcome();
    await vault.saveRoute(CrestRoute.web);
    return WebOutcome(reply.url!);
  }

  Future<GateReply> _requestConfig({String? token}) async {
    final body = await attribution.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? push.token,
    );
    if (kDebugMode && EmberGateConfig.debugForcePortal) {
      body['af_status'] = 'Non-organic';
      embTrace(() => '[EMB.CREST] DEBUG force portal: af_status=Non-organic');
    }
    return exchange.request(body);
  }

  Future<void> _backgroundDispatch() async {
    try {
      await Future.wait<void>(<Future<void>>[
        push.boot(),
        attribution.awaitSignals(),
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
