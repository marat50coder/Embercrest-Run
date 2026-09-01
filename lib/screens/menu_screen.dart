import 'package:flutter/material.dart';

import '../core/atlas.dart';
import '../core/audio.dart';
import '../core/palette.dart';
import '../core/save.dart';
import '../game/config.dart';
import '../ui/sprite_image.dart';
import '../ui/widgets.dart';
import 'game_screen.dart';
import 'panels.dart';

/// The home screen: logo and records on the left, actions on the right.
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.atlas});
  final SpriteAtlas atlas;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  Save get save => Save.instance;

  @override
  void initState() {
    super.initState();
    Audio.instance.playMusic(Sfx.growing);
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  Future<void> _openPanel(Widget panel) async {
    Audio.instance.play(Sfx.menuOpen);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'panel',
      barrierColor: const Color(0xCC070305),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => panel,
      transitionBuilder: (_, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(curved),
              child: child),
        );
      },
    );
    Audio.instance.play(Sfx.menuClose);
    if (mounted) setState(() {});
  }

  Future<void> _play() async {
    await Audio.instance.stopMusic();
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, _, _) => GameScreen(atlas: widget.atlas),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    if (!mounted) return;
    setState(() {});
    Audio.instance.playMusic(Sfx.growing);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 380;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _background(),
          // Keeps the corners calm so the logo and buttons stay legible.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.95,
                colors: [Color(0x00000000), Color(0x99080304)],
                stops: [0.45, 1.0],
              ),
            ),
            child: SizedBox.expand(),
          ),
          const EmberField(count: 30),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 20 : 32, vertical: compact ? 8 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _wallet(),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(flex: 5, child: _brand(compact)),
                        const SizedBox(width: 20),
                        Expanded(flex: 4, child: _actions(compact)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ background
  Widget _background() {
    return AnimatedBuilder(
      animation: _idle,
      builder: (_, _) {
        final t = _idle.value;
        return Transform.scale(
          scale: 1.08 + t * 0.05,
          child: Transform.translate(
            offset: Offset(-14 + t * 28, -8 + t * 16),
            child: Image.asset(
              Biome.all.last.background,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              // Dark enough for the UI to read, light enough that the caldera
              // is still recognisable behind it.
              color: const Color(0x99150809),
              colorBlendMode: BlendMode.darken,
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------ wallet row
  Widget _wallet() {
    final wallet = save.wallet;
    return RiseIn(
      child: Row(
        children: [
          for (final kind in ResourceKind.values) ...[
            ResourceChip(
              compact: true,
              color: ResourceInfo.map[kind]!.color,
              amount: wallet[kind] ?? 0,
              image: SpriteImage(
                  atlas: widget.atlas, name: ResourceInfo.map[kind]!.sprites.first),
            ),
            const SizedBox(width: 8),
          ],
          const Spacer(),
          IconTile(
            icon: Icons.settings_rounded,
            label: 'SETTINGS',
            size: 40,
            onTap: () => _openPanel(SettingsPanel(save: save)),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ left side
  Widget _brand(bool compact) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RiseIn(
            child: AnimatedBuilder(
              animation: _idle,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, -6 + _idle.value * 12),
                child: child,
              ),
              child: Image.asset(
                'assets/crest_wordmark.webp',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
        RiseIn(
          delay: const Duration(milliseconds: 120),
          child: Row(
            children: [
              _record('BEST', '${save.bestDistance} m', Pal.emberBright),
              const SizedBox(width: 10),
              _record('LONGEST CREST', '${save.bestChain}', Pal.crystal),
              const SizedBox(width: 10),
              _record('RUNS', '${save.totalRuns}', Pal.muted),
            ],
          ),
        ),
        SizedBox(height: compact ? 4 : 10),
      ],
    );
  }

  Widget _record(String label, String value, Color color) {
    return StonePanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Pal.label(9, color: Pal.muted)),
          const SizedBox(height: 2),
          Text(value, style: Pal.number(16, color: color)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ right side
  Widget _actions(bool compact) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RiseIn(
          delay: const Duration(milliseconds: 80),
          child: MagmaButton(
            label: 'START RUN',
            icon: Icons.local_fire_department_rounded,
            height: compact ? 54 : 66,
            fontSize: compact ? 19 : 23,
            onTap: _play,
          ),
        ),
        SizedBox(height: compact ? 12 : 20),
        RiseIn(
          delay: const Duration(milliseconds: 180),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconTile(
                icon: Icons.person_rounded,
                label: 'HEROES',
                size: compact ? 48 : 56,
                onTap: () => _openPanel(
                    SkinsPanel(atlas: widget.atlas, save: save)),
              ),
              IconTile(
                icon: Icons.task_alt_rounded,
                label: 'QUESTS',
                size: compact ? 48 : 56,
                onTap: () => _openPanel(QuestsPanel(save: save)),
              ),
              IconTile(
                icon: Icons.auto_awesome_mosaic_rounded,
                label: 'COLLECTION',
                size: compact ? 48 : 56,
                onTap: () => _openPanel(
                    CollectionPanel(atlas: widget.atlas, save: save)),
              ),
              IconTile(
                icon: Icons.help_outline_rounded,
                label: 'HOW TO',
                size: compact ? 48 : 56,
                onTap: () => _openPanel(HowToPanel(atlas: widget.atlas)),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 10 : 18),
        RiseIn(
          delay: const Duration(milliseconds: 260),
          child: StonePanel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            radius: 14,
            child: Row(
              children: [
                Icon(Icons.terrain_rounded, size: 16, color: Pal.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${save.biomesSeen} of ${Biome.all.length} biomes • '
                    '${save.artifacts.length} of ${Artifacts.all.length} artifacts',
                    style: Pal.label(11, color: Pal.muted, w: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
