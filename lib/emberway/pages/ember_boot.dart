import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/palette.dart';
import '../../screens/loading_screen.dart';
import '../core/gate_models.dart';
import '../crest_coordinator.dart';
import 'ember_portal.dart';
import 'offline_screen.dart';
import 'permit_screen.dart';

/// Gray-flow splash + router. Shows the Embercrest loading art (orientation
/// aware) while [CrestCoordinator.decide] runs the attribution → config
/// pipeline, then routes to the WebView (gray) or the native game (organic).
///
/// The organic path hands off to the game's own [LoadingScreen], which does
/// the heavy asset/audio load and then locks landscape.
class EmberBoot extends StatefulWidget {
  const EmberBoot({super.key, this.coordinator});

  final CrestCoordinator? coordinator;

  @override
  State<EmberBoot> createState() => _EmberBootState();
}

class _EmberBootState extends State<EmberBoot> {
  double _hatchProgress = 0;
  CrestOutcome? _outcome;
  bool _started = false;
  bool _navigating = false;
  late final DateTime _startTime;
  Timer? _hardDeadline;
  static const Duration _minSplash = Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Safety net ONLY. The coordinator's own awaits are time-boxed and always
    // return (push boot + attribution + config ~= 35s worst case on a slow
    // first launch), so this is set well above that. It must NEVER fabricate a
    // GameOutcome — that would wrongly hide the gray path from a paid user on a
    // slow network. If the pipeline truly stalls, fall back to the offline
    // screen whose Retry re-runs the whole pipeline.
    _hardDeadline = Timer(const Duration(seconds: 45), _onDeadline);
  }

  void _onDeadline() {
    if (!mounted || _navigating || _outcome != null) return;
    _outcome = widget.coordinator == null
        ? const GameOutcome()
        : const DarkOutcome(returnToGame: false);
    _maybeNavigate();
  }

  @override
  void dispose() {
    _hardDeadline?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final coordinator = widget.coordinator;
    if (coordinator == null) {
      _outcome = const GameOutcome();
      _hatchProgress = 1;
      _maybeNavigate();
      return;
    }
    try {
      _outcome = await coordinator.decide(
        onProgress: (value) {
          if (mounted) setState(() => _hatchProgress = value.clamp(0.0, 1.0));
        },
      );
    } catch (_) {
      _outcome = const GameOutcome();
    }
    if (mounted) setState(() => _hatchProgress = 1);
    _hardDeadline?.cancel();
    _maybeNavigate();
  }

  Future<void> _maybeNavigate() async {
    if (_navigating || _outcome == null) return;
    final elapsed = DateTime.now().difference(_startTime);
    if (elapsed < _minSplash) {
      await Future<void>.delayed(_minSplash - elapsed);
    }
    if (!mounted || _navigating) return;
    _navigating = true;
    await _open(_outcome!);
  }

  Future<void> _open(CrestOutcome outcome) async {
    final coordinator = widget.coordinator;
    final navigator = Navigator.of(context);

    // Organic / gate disabled → native game. Do NOT force portrait here — the
    // game's LoadingScreen manages orientation and locks landscape itself.
    if (outcome is GameOutcome || coordinator == null) {
      navigator.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoadingScreen()),
      );
      return;
    }

    // Gray path screens open portrait-first; lock portrait before routing.
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;

    if (outcome is DarkOutcome) {
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OfflineCrest(
            watch: coordinator.watch,
            retryBuilder: (_) => EmberBoot(coordinator: coordinator),
          ),
        ),
      );
      return;
    }

    if (outcome is WebOutcome) {
      Widget portalBuilder(BuildContext _) => EmberPortal(
            url: outcome.url,
            coldLaunch: outcome.coldLaunch,
            vault: coordinator.vault,
            watch: coordinator.watch,
            push: coordinator.push,
            agent: coordinator.agent,
          );

      if (coordinator.vault.shouldShowPushInvite &&
          await coordinator.push.canOfferPermission()) {
        if (!mounted) return;
        navigator.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => PushPermitScreen(
              vault: coordinator.vault,
              push: coordinator.push,
              nextBuilder: portalBuilder,
            ),
          ),
        );
      } else {
        navigator
            .pushReplacement(MaterialPageRoute<void>(builder: portalBuilder));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final portrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final art = portrait
        ? 'assets/Vertical_Loading_Screen.webp'
        : 'assets/Horizontal_Loading_Screen.webp';
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Pal.ash,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            art,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const ColoredBox(color: Pal.ash),
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
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: portrait ? 60 : 30),
                child: SizedBox(
                  width: portrait ? screenW * 0.72 : screenW * 0.44,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BootBar(progress: _hatchProgress),
                      const SizedBox(height: 12),
                      Text('EMBERCREST RUN',
                          style: Pal.label(13, color: Pal.emberBright)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BootBar extends StatelessWidget {
  const _BootBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: Pal.basalt.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Pal.emberDeep, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
              builder: (context, value, _) => FractionallySizedBox(
                widthFactor: value <= 0 ? 0.001 : value,
                child: const DecoratedBox(
                  decoration: BoxDecoration(gradient: Pal.emberGradient),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
