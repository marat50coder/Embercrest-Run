import 'dart:math' as math;

// Flutter's physics layer also exports a `Simulation`; the game's own class is
// the one meant here.
import 'package:flutter/material.dart' hide Simulation;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/atlas.dart';
import '../core/audio.dart';
import '../core/palette.dart';
import '../core/save.dart';
import '../game/config.dart';
import '../game/renderer.dart';
import '../game/simulation.dart';
import '../ui/sprite_image.dart';
import '../ui/widgets.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.atlas});
  final SpriteAtlas atlas;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Simulation _sim;
  late final GameRenderer _renderer;
  late final Ticker _ticker;
  final BackgroundCache _backgrounds = BackgroundCache();

  /// Drives the canvas repaint without rebuilding any widgets.
  final ValueNotifier<int> _frame = ValueNotifier(0);

  /// Drives the HUD at a much lower rate than the game loop.
  final ValueNotifier<int> _hud = ValueNotifier(0);

  double _camX = 0, _camY = 0;
  Duration _last = Duration.zero;
  double _hudAccum = 0;
  bool _paused = false;
  bool _finished = false;
  RunResult? _result;
  bool _isRecord = false;
  List<Quest> _questsDone = const [];

  int _loadedBiome = -1;
  _Banner? _banner;

  // flick detection
  double _flickDx = 0;
  double _flickTime = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);

    _sim = Simulation(widget.atlas)
      ..shakeEnabled = Save.instance.shakeOn
      ..onBanner = _showBanner
      ..onGameOver = _finish;
    _renderer = GameRenderer(widget.atlas)
      ..heroSkin = Save.instance.selectedSkin;

    _camX = _sim.heroX;
    _camY = _sim.heroY;
    _sim.start();
    _syncBackground();

    Audio.instance.playMusic(Sfx.heatWave);
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    _frame.dispose();
    _hud.dispose();
    _backgrounds.dispose();
    _renderer.dispose();
    Audio.instance.stopMusic();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `inactive` fires for momentary things like the notification shade peeking
    // in, so only a real background transition should interrupt a run.
    final backgrounded = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (backgrounded && !_finished && !_paused) {
      setState(() => _paused = true);
    }
  }

  // ------------------------------------------------------------ background
  Future<void> _syncBackground() async {
    if (_loadedBiome == _sim.biomeIndex) return;
    _loadedBiome = _sim.biomeIndex;
    final image = await _backgrounds.get(_sim.biome.background);
    if (!mounted) return;
    _renderer.background = image;
  }

  // ------------------------------------------------------------ loop
  void _tick(Duration elapsed) {
    if (_last == Duration.zero) {
      _last = elapsed;
      return;
    }
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    // A long stall (garbage collection, app switch) must not teleport the hero.
    dt = dt.clamp(0.0, 1 / 25);

    if (!_paused && !_finished) {
      _sim.update(dt);
      if (_loadedBiome != _sim.biomeIndex) _syncBackground();

      final look = 165.0;
      final tx = _sim.heroX + math.cos(_sim.heading) * look;
      final ty = _sim.heroY + math.sin(_sim.heading) * look;
      final k = math.min(1.0, dt * 3.6);
      _camX += (tx - _camX) * k;
      _camY += (ty - _camY) * k;

      _hudAccum += dt;
      if (_hudAccum >= 0.07) {
        _hudAccum = 0;
        _hud.value++;
      }
      if (_banner != null && _sim.time > _banner!.until) {
        _banner = null;
        _hud.value++;
      }
    }
    _frame.value++;
  }

  void _showBanner(String message, int color) {
    _banner = _Banner(message, color, _sim.time + 1.6);
    _hud.value++;
  }

  // ------------------------------------------------------------ input
  bool _onKey(KeyEvent event) {
    if (_paused || _finished) return false;
    final down = event is! KeyUpEvent;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.keyA:
        _sim.setSteer(down ? -1 : 0);
        return true;
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.keyD:
        _sim.setSteer(down ? 1 : 0);
        return true;
      case LogicalKeyboardKey.space:
        if (event is KeyDownEvent) _sim.crystallize();
        return true;
    }
    return false;
  }

  void _pointerSteer(Offset local, Size size) {
    if (_paused || _finished) return;
    final centre = size.width / 2;
    _sim.setSteer((local.dx - centre) / (size.width * 0.28));
  }

  void _pointerMove(PointerMoveEvent e, Size size) {
    _pointerSteer(e.localPosition, size);
    // A quick horizontal flick snaps the crest instead of easing into a turn.
    final now = _sim.time;
    if (now - _flickTime > 0.12) {
      _flickDx = 0;
      _flickTime = now;
    }
    _flickDx += e.delta.dx;
    if (_flickDx.abs() > size.width * 0.13) {
      _sim.sharpTurn(_flickDx.sign.toInt());
      _flickDx = 0;
    }
  }

  // ------------------------------------------------------------ end of run
  void _finish() {
    if (_finished) return;
    final result = _sim.result;
    // Read the old record before committing, or the run always looks like one.
    final beatRecord =
        result.distance > 0 && result.distance > Save.instance.bestDistance;
    _questsDone = Save.instance.commitRun(result);
    setState(() {
      _finished = true;
      _result = result;
      _isRecord = beatRecord;
    });
    Audio.instance.stopMusic();
    if (_questsDone.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) Audio.instance.play(Sfx.victory, volume: 0.9);
      });
    }
  }

  void _retry() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => GameScreen(atlas: widget.atlas),
        transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
      ),
    );
  }

  // ------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: Pal.ash,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _ScenePainter(_renderer, _sim, this, _frame),
              size: Size.infinite,
            ),
          ),
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) => _pointerSteer(e.localPosition, size),
            onPointerMove: (e) => _pointerMove(e, size),
            onPointerUp: (_) => _sim.setSteer(0),
            onPointerCancel: (_) => _sim.setSteer(0),
          ),
          SafeArea(
            child: ValueListenableBuilder<int>(
              valueListenable: _hud,
              builder: (_, _, _) => _Hud(
                sim: _sim,
                atlas: widget.atlas,
                banner: _banner,
                onPause: () => setState(() => _paused = true),
                onCrystallise: _sim.crystallize,
                leftHanded: Save.instance.leftHanded,
              ),
            ),
          ),
          if (_paused && !_finished)
            _PauseOverlay(
              onResume: () => setState(() => _paused = false),
              onRestart: _retry,
              onQuit: () => Navigator.of(context).pop(),
            ),
          if (_finished && _result != null)
            _GameOverOverlay(
              atlas: widget.atlas,
              result: _result!,
              isRecord: _isRecord,
              cause: _sim.deathCause ?? 'THE CREST FAILED',
              questsDone: _questsDone,
              onRetry: _retry,
              onMenu: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  double get camX => _camX;
  double get camY => _camY;
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.renderer, this.sim, this.screen, Listenable repaint)
      : super(repaint: repaint);

  final GameRenderer renderer;
  final Simulation sim;
  final _GameScreenState screen;

  @override
  void paint(Canvas canvas, Size size) {
    renderer.paint(canvas, size, sim, screen.camX, screen.camY);
  }

  @override
  bool shouldRepaint(_ScenePainter old) => false;
}

class _Banner {
  final String message;
  final int color;
  final double until;
  _Banner(this.message, this.color, this.until);
}

// ------------------------------------------------------------------- HUD

class _Hud extends StatelessWidget {
  const _Hud({
    required this.sim,
    required this.atlas,
    required this.banner,
    required this.onPause,
    required this.onCrystallise,
    required this.leftHanded,
  });

  final Simulation sim;
  final SpriteAtlas atlas;
  final _Banner? banner;
  final VoidCallback onPause;
  final VoidCallback onCrystallise;
  final bool leftHanded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _distanceBlock(),
              const SizedBox(width: 12),
              Expanded(child: _meters()),
              const SizedBox(width: 12),
              _resources(),
              const SizedBox(width: 10),
              Pressable(
                onTap: onPause,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xAA1A1013),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x66FF7A18)),
                  ),
                  child: const Icon(Icons.pause_rounded,
                      color: Pal.emberBright, size: 20),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (banner != null)
            Center(
              child: AnimatedOpacity(
                opacity: 1,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xCC120A0C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Color(banner!.color)),
                    boxShadow: [
                      BoxShadow(
                          color: Color(banner!.color).withValues(alpha: 0.35),
                          blurRadius: 22),
                    ],
                  ),
                  child: Text(banner!.message,
                      style: Pal.label(15, color: Color(banner!.color))),
                ),
              ),
            ),
          const Spacer(),
          Row(
            children: [
              if (!leftHanded) const Spacer(),
              _crystalButton(),
              if (leftHanded) const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _distanceBlock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xAA120A0C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x55FF7A18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${sim.distance}', style: Pal.number(26)),
              const SizedBox(width: 3),
              Text('m', style: Pal.label(12, color: Pal.muted)),
              if (sim.combo > 1) ...[
                const SizedBox(width: 10),
                Text('x${sim.comboMultiplier.toStringAsFixed(1)}',
                    style: Pal.number(16, color: Pal.gold)),
              ],
            ],
          ),
          Text(
            'BEST ${Save.instance.bestDistance} m   •   CREST ${sim.chainLength}',
            style: Pal.label(9.5, color: Pal.muted),
          ),
        ],
      ),
    );
  }

  Widget _meters() {
    final magma = sim.activeMagma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x99120A0C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33FF7A18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _meterRow('MAGMA ENERGY', sim.energyFraction,
              sim.energyFraction < 0.25 ? Pal.danger : Pal.ember),
          const SizedBox(height: 6),
          _meterRow('PRESSURE', sim.pressureFraction,
              sim.pressureFraction > 0.78 ? Pal.danger : Pal.gold),
          if (magma != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 88,
                  child: Text(
                    MagmaInfo.of(magma).label.split(' ').first.toUpperCase(),
                    style: Pal.label(9, color: MagmaInfo.of(magma).color),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MeterBar(
                    value: sim.magmaFraction,
                    color: MagmaInfo.of(magma).color,
                    height: 7,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _meterRow(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: Pal.label(9, color: Pal.muted)),
        ),
        const SizedBox(width: 8),
        Expanded(child: MeterBar(value: value, color: color, height: 7)),
      ],
    );
  }

  Widget _resources() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final kind in ResourceKind.values)
          if ((sim.collected[kind] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: ResourceChip(
                compact: true,
                color: ResourceInfo.map[kind]!.color,
                amount: sim.collected[kind]!,
                image: SpriteImage(
                    atlas: atlas, name: ResourceInfo.map[kind]!.sprites.first),
              ),
            ),
      ],
    );
  }

  Widget _crystalButton() {
    final ready = sim.crystalReady;
    final progress =
        1 - (sim.crystalTimer / Simulation.crystalCooldown).clamp(0.0, 1.0);
    return Pressable(
      onTap: onCrystallise,
      enabled: ready,
      sound: null,
      child: SizedBox(
        width: 62,
        height: 62,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xCC101A22),
                border: Border.all(
                    color: ready ? Pal.crystal : const Color(0xFF33434D),
                    width: 2),
                boxShadow: ready
                    ? [
                        BoxShadow(
                            color: Pal.crystal.withValues(alpha: 0.4),
                            blurRadius: 18)
                      ]
                    : null,
              ),
            ),
            if (!ready)
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  color: Pal.crystal.withValues(alpha: 0.6),
                  backgroundColor: Colors.transparent,
                ),
              ),
            Icon(Icons.ac_unit_rounded,
                color: ready ? Pal.crystal : const Color(0xFF54646E), size: 26),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ pause

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xD9070305),
      child: Center(
        child: StonePanel(
          glow: true,
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PAUSED', style: Pal.title(26)),
              const SizedBox(height: 20),
              MagmaButton(label: 'RESUME', width: 230, onTap: onResume),
              const SizedBox(height: 10),
              MagmaButton(
                  label: 'RESTART',
                  width: 230,
                  height: 50,
                  fontSize: 17,
                  tone: Pal.stoneGradient,
                  onTap: onRestart),
              const SizedBox(height: 10),
              MagmaButton(
                  label: 'QUIT TO MENU',
                  width: 230,
                  height: 50,
                  fontSize: 17,
                  tone: Pal.stoneGradient,
                  onTap: onQuit),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- game over

class _GameOverOverlay extends StatefulWidget {
  const _GameOverOverlay({
    required this.atlas,
    required this.result,
    required this.isRecord,
    required this.cause,
    required this.questsDone,
    required this.onRetry,
    required this.onMenu,
  });

  final SpriteAtlas atlas;
  final RunResult result;
  final bool isRecord;
  final String cause;
  final List<Quest> questsDone;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  @override
  State<_GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<_GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(begin: 40.0, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(
          offset: Offset(0, _slide.value),
          child: child,
        ),
      ),
      child: Container(
        color: const Color(0xD9060204),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: StonePanel(
              glow: true,
              padding: const EdgeInsets.fromLTRB(30, 24, 30, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── red "YOU LOSE" header ──
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        Color(0xFF7A0A00),
                        Color(0xFFBF1200),
                        Color(0xFF7A0A00),
                      ]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xAAFF2010),
                            blurRadius: 20,
                            spreadRadius: 2),
                      ],
                    ),
                    child: Text(
                      'YOU LOSE',
                      style: Pal.title(32).copyWith(
                        color: Colors.white,
                        letterSpacing: 4,
                        shadows: [
                          const Shadow(
                              color: Color(0xFFFF6040),
                              blurRadius: 12,
                              offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  ),

                  // ── death reason ──
                  Text(widget.cause,
                      style: Pal.label(12, color: Pal.danger),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),

                  // ── record badge (optional) ──
                  if (widget.isRecord)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0x33FFD166),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Pal.gold, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events_rounded,
                              size: 16, color: Pal.gold),
                          const SizedBox(width: 6),
                          Text('NEW RECORD',
                              style: Pal.label(12, color: Pal.gold)),
                        ],
                      ),
                    ),

                  // ── stats row ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _stat('DISTANCE', '${r.distance} m', Pal.emberBright),
                      _stat('SCORE', '${r.score}', Pal.gold),
                      _stat('CREST', '${r.longestChain}', Pal.crystal),
                      _stat('CORES', '${r.coresActivated}', Pal.obsidian),
                    ],
                  ),

                  // ── collected resources ──
                  if (r.totalCollected > 0) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in r.collected.entries)
                          if (e.value > 0)
                            ResourceChip(
                              compact: true,
                              color: ResourceInfo.map[e.key]!.color,
                              amount: e.value,
                              image: SpriteImage(
                                  atlas: widget.atlas,
                                  name:
                                      ResourceInfo.map[e.key]!.sprites.first),
                            ),
                      ],
                    ),
                  ],

                  // ── completed quests ──
                  if (widget.questsDone.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    for (final q in widget.questsDone)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 15, color: Pal.emberBright),
                            const SizedBox(width: 6),
                            Text('${q.label}  +${q.reward}',
                                style: Pal.label(11, color: Pal.emberBright)),
                          ],
                        ),
                      ),
                  ],

                  const SizedBox(height: 22),

                  // ── action buttons ──
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MagmaButton(
                        label: 'MENU',
                        width: 148,
                        height: 54,
                        fontSize: 17,
                        tone: Pal.stoneGradient,
                        onTap: widget.onMenu,
                      ),
                      const SizedBox(width: 14),
                      MagmaButton(
                        label: 'PLAY AGAIN',
                        width: 190,
                        height: 54,
                        fontSize: 18,
                        onTap: widget.onRetry,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: Pal.number(20, color: color)),
          const SizedBox(height: 2),
          Text(label, style: Pal.label(9, color: Pal.muted)),
        ],
      ),
    );
  }
}
