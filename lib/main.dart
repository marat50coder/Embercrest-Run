import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'live_ops/screens/boot.dart';
import 'live_ops/store/keystore.dart';
import 'live_ops/net/attribution.dart';
import 'live_ops/net/session.dart';
import 'live_ops/net/push.dart';
import 'live_ops/net/config_client.dart';
import 'live_ops/net/probe.dart';
import 'live_ops/config/config.dart';
import 'live_ops/config/log.dart';
import 'live_ops/flow/router.dart';
import 'core/palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final locker = AshChest();
  final mask = AgentFace();
  await Future.wait<void>(<Future<void>>[
    locker.open(),
    mask.warm(),
  ]);

  opsLog(
    () => '[BR.BOOT] pactReady=${LiveConfig.pactReady} '
        'endpoint=${LiveConfig.endpoint} '
        'afKeyLen=${LiveConfig.appsFlyerKey.length} '
        'fbNum=${LiveConfig.firebaseProjectNumber}',
  );

  var productionServicesReady = false;
  if (LiveConfig.pactReady) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(liveBgPush);
      productionServicesReady = true;
      opsLog(() => '[BR.BOOT] Firebase.initializeApp OK');
    } catch (error) {
      opsLog(() => '[BR.BOOT] Firebase.initializeApp failed: $error');
    }
  } else {
    opsLog(() => '[BR.BOOT] pact closed — native play only.');
  }

  final pulse = ReachProbe();
  final ping = AlertPipe(locker, enabled: productionServicesReady);
  final ledger = SignalBook(mask);
  final arbiter = PathJudge(
    locker: locker,
    pulse: pulse,
    ledger: ledger,
    wire: PactPost(mask, locker),
    ping: ping,
    mask: mask,
    runtimeEnabled: LiveConfig.pactReady,
  );

  runApp(EmbercrestApp(arbiter: arbiter));
}

class EmbercrestApp extends StatelessWidget {
  const EmbercrestApp({super.key, this.arbiter});

  final PathJudge? arbiter;

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
      home: LiveBoot(arbiter: arbiter),
    );
  }
}
