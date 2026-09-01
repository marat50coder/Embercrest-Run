import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/atlas.dart';
import '../core/audio.dart';
import '../core/palette.dart';
import '../core/save.dart';
import '../game/config.dart';
import '../ui/loading_mark.dart';
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
  SpriteAtlas? _atlas;
  bool _ready = false;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _precacheArt() async {
    await precacheImage(const AssetImage('assets/crest_wordmark.webp'), context);
    if (!mounted) return;
    await precacheImage(AssetImage(Biome.all.last.background), context);
  }

  Future<void> _boot() async {
    final save = await Save.load();
    if (!mounted) return;

    await Audio.instance.init(music: save.musicOn, sfx: save.sfxOn);
    if (!mounted) return;

    _atlas = await SpriteAtlas.load();
    if (!mounted) return;

    await _precacheArt();
    if (!mounted) return;

    await Audio.instance.preload(const [
      Sfx.click,
      Sfx.resource,
      Sfx.rareResource,
      Sfx.coreActivation,
      Sfx.pathCollapse,
      Sfx.freshMagma,
      Sfx.startRun,
      Sfx.gameOver,
    ]);
    if (!mounted) return;
    setState(() => _ready = true);
  }

  Future<void> _openMenu() async {
    if (_opened || _atlas == null || !mounted) return;
    _opened = true;
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
        ? 'assets/caldera_tall.webp'
        : 'assets/caldera_wide.webp';
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Pal.ash,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            art,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xCC0B0507)],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: portrait ? 74 : 34),
              child: SizedBox(
                width: portrait ? screenW * 0.72 : screenW * 0.44,
                child: LoadingMark(
                  ready: _ready,
                  onFilled: _openMenu,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
