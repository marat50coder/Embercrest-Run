import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/palette.dart';
import 'emberway/config/ember_gate_config.dart';
import 'emberway/core/ember_log.dart';
import 'emberway/crest_coordinator.dart';
import 'emberway/infra/crest_vault.dart';
import 'emberway/infra/ember_attribution.dart';
import 'emberway/infra/gate_exchange.dart';
import 'emberway/infra/net_watch.dart';
import 'emberway/infra/push_hub.dart';
import 'emberway/infra/ua_client.dart';
import 'emberway/pages/ember_boot.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loading is allowed in either orientation; the game locks to landscape once
  // the menu appears.
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final vault = CrestVault();
  final agent = UaClient();
  await Future.wait<void>(<Future<void>>[
    vault.initialize(),
    agent.prepare(),
  ]);

  embTrace(
    () => '[EMB.BOOT] credentialsReady=${EmberGateConfig.grayCredentialsReady} '
        'endpoint=${EmberGateConfig.endpoint} '
        'afKeyLen=${EmberGateConfig.appsFlyerKey.length} '
        'fbNum=${EmberGateConfig.firebaseProjectNumber}',
  );

  var productionServicesReady = false;
  if (EmberGateConfig.grayCredentialsReady) {
    try {
      await Firebase.initializeApp();
      productionServicesReady = true;
      embTrace(() => '[EMB.BOOT] Firebase.initializeApp OK');
    } catch (error) {
      embTrace(() => '[EMB.BOOT] Firebase.initializeApp failed: $error');
    }
  } else {
    embTrace(() => '[EMB.BOOT] gate DISABLED — white game only.');
  }

  final watch = NetWatch();
  // Attribution + config POST run even if Firebase failed; only push needs it.
  final push = PushHub(vault, enabled: productionServicesReady);
  final attribution = EmberAttribution(agent);
  final coordinator = CrestCoordinator(
    vault: vault,
    watch: watch,
    attribution: attribution,
    exchange: GateExchange(agent, vault),
    push: push,
    agent: agent,
    runtimeEnabled: EmberGateConfig.grayCredentialsReady,
  );

  runApp(EmbercrestApp(coordinator: coordinator));
}

class EmbercrestApp extends StatelessWidget {
  const EmbercrestApp({super.key, this.coordinator});

  final CrestCoordinator? coordinator;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Embercrest Run',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Pal.ash,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Pal.ember,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          },
        ),
      ),
      home: EmberBoot(coordinator: coordinator),
    );
  }
}
