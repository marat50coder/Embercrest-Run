import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/palette.dart';
import 'screens/loading_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loading is allowed in either orientation; the game locks to landscape once
  // the menu appears.
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const EmbercrestApp());
}

class EmbercrestApp extends StatelessWidget {
  const EmbercrestApp({super.key});

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
      home: const LoadingScreen(),
    );
  }
}
