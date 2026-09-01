import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/palette.dart';
import '../../../screens/loading_screen.dart';
import '../../../ui/loading_mark.dart';
import '../trail/judge.dart';
import '../trail/call.dart';
import 'quiet.dart';
import 'permit.dart';
import 'sheet.dart';

class CinderDawn extends StatefulWidget {
  const CinderDawn({super.key, this.arbiter});

  final PathJudge? arbiter;

  @override
  State<CinderDawn> createState() => _CinderDawnState();
}

class _CinderDawnState extends State<CinderDawn> {
  PathCall? _verdict;
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
        ? const PlayCall()
        : const QuietCall(returnToPlay: false);
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
      _verdict = const PlayCall();
      if (mounted) setState(() => _ready = true);
      return;
    }
    try {
      _verdict = await arbiter.decide(onProgress: (_) {});
    } catch (_) {
      _verdict = const PlayCall();
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

  Future<void> _open(PathCall verdict) async {
    final arbiter = widget.arbiter;
    final navigator = Navigator.of(context);

    if (verdict is PlayCall || arbiter == null) {
      navigator.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoadingScreen()),
      );
      return;
    }

    if (verdict is QuietCall) {
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => QuietLink(
            pulse: arbiter.pulse,
            retryBuilder: (_) => CinderDawn(arbiter: arbiter),
          ),
        ),
      );
      return;
    }

    if (verdict is ViewCall) {
      Widget paneBuilder(BuildContext _) => SheetHost(
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
            builder: (_) => PermitCard(
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
