import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/palette.dart';
import '../screens/loading_screen.dart';
import '../ui/loading_mark.dart';
import 'arbiter.dart';
import 'gap.dart';
import 'notice.dart';
import 'pane.dart';
import 'verdicts.dart';

class RidgeAwake extends StatefulWidget {
  const RidgeAwake({super.key, this.arbiter});

  final TrailArbiter? arbiter;

  @override
  State<RidgeAwake> createState() => _RidgeAwakeState();
}

class _RidgeAwakeState extends State<RidgeAwake> {
  TrailVerdict? _verdict;
  bool _ready = false;
  bool _started = false;
  bool _navigating = false;
  Timer? _hardDeadline;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _hardDeadline = Timer(const Duration(seconds: 48), _onDeadline);
  }

  void _onDeadline() {
    if (!mounted || _navigating || _verdict != null) return;
    _verdict = widget.arbiter == null
        ? const PlayVerdict()
        : const GloomVerdict(returnToPlay: false);
    setState(() => _ready = true);
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
    final arbiter = widget.arbiter;
    if (arbiter == null) {
      _verdict = const PlayVerdict();
      if (mounted) setState(() => _ready = true);
      return;
    }
    try {
      _verdict = await arbiter.decide(onProgress: (_) {});
    } catch (_) {
      _verdict = const PlayVerdict();
    }
    _hardDeadline?.cancel();
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _maybeNavigate() async {
    if (_navigating || _verdict == null) return;
    if (!mounted || _navigating) return;
    _navigating = true;
    await _open(_verdict!);
  }

  Future<void> _open(TrailVerdict verdict) async {
    final arbiter = widget.arbiter;
    final navigator = Navigator.of(context);

    if (verdict is PlayVerdict || arbiter == null) {
      navigator.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoadingScreen()),
      );
      return;
    }

    if (verdict is GloomVerdict) {
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SignalGap(
            pulse: arbiter.pulse,
            retryBuilder: (_) => RidgeAwake(arbiter: arbiter),
          ),
        ),
      );
      return;
    }

    if (verdict is ViewVerdict) {
      Widget paneBuilder(BuildContext _) => RiftPane(
            url: verdict.url,
            coldLaunch: verdict.coldLaunch,
            locker: arbiter.locker,
            pulse: arbiter.pulse,
            ping: arbiter.ping,
            mask: arbiter.mask,
          );

      var showNotice = false;
      try {
        showNotice = arbiter.locker.shouldOfferNotice &&
            await arbiter.ping.canOfferPermission();
      } catch (_) {
        showNotice = false;
      }
      if (!mounted) return;

      if (showNotice) {
        navigator.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => NoticePermit(
              locker: arbiter.locker,
              ping: arbiter.ping,
              nextBuilder: paneBuilder,
            ),
          ),
        );
        return;
      }

      navigator.pushReplacement(MaterialPageRoute<void>(builder: paneBuilder));
    }
  }

  @override
  Widget build(BuildContext context) {
    final portrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final art = portrait
        ? 'assets/magma_boot_tall.webp'
        : 'assets/magma_boot_wide.webp';
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
                  child: LoadingMark(
                    ready: _ready,
                    onFilled: _maybeNavigate,
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
