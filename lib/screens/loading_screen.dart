import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/atlas.dart';
import '../core/audio.dart';
import '../core/palette.dart';
import '../core/save.dart';
import '../game/config.dart';
import '../ui/widgets.dart';
import 'menu_screen.dart';

/// Boots the game while showing the artwork that matches the current
/// orientation. The player may hold the device either way here; the menu locks
/// to landscape afterwards.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  double _progress = 0;
  String _status = 'Waking the volcano';
  SpriteAtlas? _atlas;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _step(double to, String status, Future<void> Function() work) async {
    if (!mounted) return;
    setState(() => _status = status);
    await work();
    if (!mounted) return;
    setState(() => _progress = to);
    // A beat between steps so the bar reads as progress rather than a jump.
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  /// Decodes the artwork the menu shows first, so it never pops in late.
  Future<void> _precacheArt() async {
    await precacheImage(const AssetImage('assets/Game_Name.webp'), context);
    if (!mounted) return;
    await precacheImage(AssetImage(Biome.all.last.background), context);
  }

  Future<void> _boot() async {
    late Save save;
    await _step(0.15, 'Reading the ledger', () async {
      save = await Save.load();
    });

    await _step(0.35, 'Lighting the speakers', () async {
      await Audio.instance.init(music: save.musicOn, sfx: save.sfxOn);
    });

    await _step(0.72, 'Carving the crest', () async {
      _atlas = await SpriteAtlas.load();
    });

    if (!mounted) return;
    setState(() => _status = 'Warming the embers');
    await _precacheArt();
    if (!mounted) return;
    setState(() => _progress = 0.88);

    await _step(1.0, 'Ready', () async {
      await Audio.instance.preload(const [
        Sfx.click, Sfx.resource, Sfx.rareResource, Sfx.coreActivation,
        Sfx.pathCollapse, Sfx.freshMagma, Sfx.startRun, Sfx.gameOver,
      ]);
    });

    if (!mounted) return;
    // From here on the game is landscape only.
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (_, _, _) => MenuScreen(atlas: _atlas!),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final portrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final art = portrait
        ? 'assets/Vertical_Loading_Screen.webp'
        : 'assets/Horizontal_Loading_Screen.webp';

    return Scaffold(
      backgroundColor: Pal.ash,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Both artworks are full-bleed; cover keeps them uncropped on the
          // long axis whichever way the device is held.
          Image.asset(art, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xCC0B0507)],
              ),
            ),
          ),
          const EmberField(count: 22),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: portrait ? 74 : 34),
              child: SizedBox(
                width: portrait ? 300 : 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_status.toUpperCase(),
                        style: Pal.label(12, color: Pal.muted)),
                    const SizedBox(height: 10),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: _progress),
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOut,
                      builder: (_, v, _) =>
                          MeterBar(value: v, color: Pal.ember, height: 10),
                    ),
                    const SizedBox(height: 12),
                    Text('EMBERCREST RUN',
                        style: Pal.label(13, color: Pal.emberBright)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
