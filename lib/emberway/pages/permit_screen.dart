import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/ember_gate_config.dart';
import '../infra/crest_vault.dart';
import '../infra/push_hub.dart';

/// Push opt-in screen, shown once before the WebView on the first gray entry.
class PushPermitScreen extends StatefulWidget {
  const PushPermitScreen({
    super.key,
    required this.vault,
    required this.push,
    required this.nextBuilder,
    this.onTokenReady,
  });

  final CrestVault vault;
  final PushHub push;
  final WidgetBuilder nextBuilder;
  final Future<void> Function(String token)? onTokenReady;

  @override
  State<PushPermitScreen> createState() => _PushPermitScreenState();
}

class _PushPermitScreenState extends State<PushPermitScreen> {
  bool _working = false;

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

  Future<void> _accept() async {
    if (_working) return;
    setState(() => _working = true);
    final granted = await widget.push.askPermission();
    final token = widget.push.token;
    if (granted && token != null && token.isNotEmpty) {
      await widget.onTokenReady?.call(token);
    }
    if (!granted) await _snooze();
    _continue();
  }

  Future<void> _skip() async {
    if (_working) return;
    setState(() => _working = true);
    await _snooze();
    _continue();
  }

  Future<void> _snooze() {
    final until = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        EmberGateConfig.pushSnoozeSeconds;
    return widget.vault.snoozePushInvite(until);
  }

  void _continue() {
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: widget.nextBuilder));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final background = landscape
        ? 'assets/Horizontal_Notifications_Screen.webp'
        : 'assets/Vertical_Notifications_Screen.webp';
    // Landscape (Horizontal_Notifications_Screen) buttons are 25% smaller than
    // the portrait ones so they sit better on the wide artwork.
    final width = landscape
        ? (media.size.width * 0.315).clamp(240.0, 420.0)
        : (media.size.width * 0.80).clamp(280.0, 440.0);
    final acceptH = landscape ? 49.5 : 74.0;
    final skipH = landscape ? 43.5 : 64.0;
    final acceptFont = landscape ? 16.5 : 25.0;
    final skipFont = landscape ? 15.0 : 22.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            background,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          Align(
            alignment: Alignment(0, landscape ? 0.80 : 0.90),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _PermitButton(
                  width: width,
                  height: acceptH,
                  fontSize: acceptFont,
                  label: 'Allow',
                  emphasized: true,
                  busy: _working,
                  onTap: _accept,
                ),
                SizedBox(height: landscape ? 12 : 16),
                _PermitButton(
                  width: width * 0.9,
                  height: skipH,
                  fontSize: skipFont,
                  label: 'Not now',
                  emphasized: false,
                  busy: false,
                  onTap: _skip,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermitButton extends StatelessWidget {
  const _PermitButton({
    required this.width,
    required this.height,
    required this.fontSize,
    required this.label,
    required this.emphasized,
    required this.busy,
    required this.onTap,
  });

  final double width;
  final double height;
  final double fontSize;
  final String label;
  final bool emphasized;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = height / 2;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            colors: emphasized
                ? const <Color>[Color(0xFFFFC24A), Color(0xFFFF7A18)]
                : const <Color>[Color(0xFFFF9A3D), Color(0xFFD8380B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: const Color(0xFF5A2410), width: 3),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 5)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: busy ? null : onTap,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: Color(0xFF3A1608),
                      ),
                    )
                  : Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF3A1608),
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
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
