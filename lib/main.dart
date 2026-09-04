import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cinder/face/dawn.dart';
import 'cinder/hold/chest.dart';
import 'cinder/net/book.dart';
import 'cinder/net/face.dart';
import 'cinder/net/pipe.dart';
import 'cinder/net/post.dart';
import 'cinder/net/probe.dart';
import 'cinder/pact/pact.dart';
import 'cinder/pact/trace.dart';
import 'cinder/trail/judge.dart';
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

  cinderLog(
    () => '[BR.BOOT] pactReady=${CinderPact.pactReady} '
        'endpoint=${CinderPact.endpoint} '
        'afKeyLen=${CinderPact.appsFlyerKey.length} '
        'fbNum=${CinderPact.firebaseProjectNumber}',
  );

  var productionServicesReady = false;
  if (CinderPact.pactReady) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(cinderBgPing);
      productionServicesReady = true;
      cinderLog(() => '[BR.BOOT] Firebase.initializeApp OK');
    } catch (error) {
      cinderLog(() => '[BR.BOOT] Firebase.initializeApp failed: $error');
    }
  } else {
    cinderLog(() => '[BR.BOOT] pact closed — native play only.');
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
    runtimeEnabled: CinderPact.pactReady,
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
      home: CinderDawn(arbiter: arbiter),
    );
  }
}
