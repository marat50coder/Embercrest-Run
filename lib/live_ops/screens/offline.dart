import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../net/probe.dart';

class QuietLink extends StatefulWidget {
  const QuietLink({
    super.key,
    required this.pulse,
    required this.retryBuilder,
  });

  final ReachProbe pulse;
  final WidgetBuilder retryBuilder;

  @override
  State<QuietLink> createState() => _QuietLinkState();
}

class _QuietLinkState extends State<QuietLink> {
  bool _checking = false;
  bool _stillOffline = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _retry() async {
    if (_checking) return;
    HapticFeedback.lightImpact();
    setState(() {
      _checking = true;
      _stillOffline = false;
    });
    bool online = false;
    try {
      online = await widget.pulse.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (!mounted) return;
    if (online) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: widget.retryBuilder),
      );
      return;
    }
    setState(() {
      _checking = false;
      _stillOffline = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final width = landscape
        ? (media.size.width * 0.40).clamp(300.0, 520.0)
        : (media.size.width * 0.72).clamp(260.0, 420.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF1A0C0A),
              Color(0xFF000000),
              Color(0xFF0B0507),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: Color(0xFFFFC24A),
                    size: 72,
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'NO INTERNET CONNECTION',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Check your connection and try again',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFD6D6D6),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _RetryChip(
                    width: width,
                    height: landscape ? 64.0 : 72.0,
                    busy: _checking,
                    onTap: _retry,
                  ),
                  if (_stillOffline)
                    const Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: Text(
                        'Still offline',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RetryChip extends StatelessWidget {
  const _RetryChip({
    required this.width,
    required this.height,
    required this.busy,
    required this.onTap,
  });

  final double width;
  final double height;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFFFB037), Color(0xFFC42A08)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: const Color(0xFF4A1C0C), width: 2.5),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: busy ? null : onTap,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        color: Color(0xFF2E1206),
                      ),
                    )
                  : const Text(
                      'Retry',
                      style: TextStyle(
                        color: Color(0xFF2E1206),
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        height: 1.0,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
