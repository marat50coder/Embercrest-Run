import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/palette.dart';
import 'ridgeline/arbiter.dart';
import 'ridgeline/awake.dart';
import 'ridgeline/ledger.dart';
import 'ridgeline/locker.dart';
import 'ridgeline/mask.dart';
import 'ridgeline/note.dart';
import 'ridgeline/pact.dart';
import 'ridgeline/ping.dart';
import 'ridgeline/pulse.dart';
import 'ridgeline/wire.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final locker = TrailLocker();
  final mask = SafariMask();
  await Future.wait<void>(<Future<void>>[
    locker.open(),
    mask.warm(),
  ]);

  riftNote(
    () => '[RIFT.BOOT] pactReady=${RidgePact.pactReady} '
        'endpoint=${RidgePact.endpoint} '
        'afKeyLen=${RidgePact.appsFlyerKey.length} '
        'fbNum=${RidgePact.firebaseProjectNumber}',
  );

  var productionServicesReady = false;
  if (RidgePact.pactReady) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(riftBackgroundPing);
      productionServicesReady = true;
      riftNote(() => '[RIFT.BOOT] Firebase.initializeApp OK');
    } catch (error) {
      riftNote(() => '[RIFT.BOOT] Firebase.initializeApp failed: $error');
    }
  } else {
    riftNote(() => '[RIFT.BOOT] pact closed — native play only.');
  }

  final pulse = LinkPulse();
  final ping = PingRelay(locker, enabled: productionServicesReady);
  final ledger = FlightLedger(mask);
  final arbiter = TrailArbiter(
    locker: locker,
    pulse: pulse,
    ledger: ledger,
    wire: PactWire(mask, locker),
    ping: ping,
    mask: mask,
    runtimeEnabled: RidgePact.pactReady,
  );

  runApp(EmbercrestApp(arbiter: arbiter));
}

class EmbercrestApp extends StatelessWidget {
  const EmbercrestApp({super.key, this.arbiter});

  final TrailArbiter? arbiter;

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
      home: RidgeAwake(arbiter: arbiter),
    );
  }
}
