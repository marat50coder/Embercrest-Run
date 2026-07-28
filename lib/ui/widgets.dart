import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/palette.dart';

/// Scales down slightly while held. Used by every tappable control so the
/// whole app reacts the same way to touch.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.sound = Sfx.click,
    this.scale = 0.94,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onTap;
  final String? sound;
  final double scale;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: widget.enabled ? () => setState(() => _down = false) : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _down = false);
              if (widget.sound != null) Audio.instance.play(widget.sound!);
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Opacity(opacity: widget.enabled ? 1 : 0.45, child: widget.child),
      ),
    );
  }
}

/// The primary call-to-action button: molten fill, carved rim, warm glow.
class MagmaButton extends StatelessWidget {
  const MagmaButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.width,
    this.height = 62,
    this.fontSize = 22,
    this.enabled = true,
    this.tone = Pal.emberGradient,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final double? width;
  final double height;
  final double fontSize;
  final bool enabled;
  final Gradient tone;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      enabled: enabled,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        decoration: BoxDecoration(
          gradient: tone,
          borderRadius: BorderRadius.circular(height / 2.6),
          border: Border.all(color: const Color(0xFF4A2418), width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Pal.ember.withValues(alpha: 0.45),
              blurRadius: 26,
              spreadRadius: -4,
              offset: const Offset(0, 6),
            ),
            const BoxShadow(
              color: Color(0x66000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glass highlight across the top half.
            Positioned(
              top: 3,
              left: 10,
              right: 10,
              height: height * 0.34,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height / 3),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.34),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: fontSize + 4, color: const Color(0xFF3A1A0C)),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                    color: const Color(0xFF35150A),
                    shadows: [
                      Shadow(
                          color: Colors.white.withValues(alpha: 0.35),
                          offset: const Offset(0, 1)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A dark basalt surface used for panels, dialogs and HUD chips.
class StonePanel extends StatelessWidget {
  const StonePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.glow = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: Pal.stoneGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFF573036), width: 1.6),
        boxShadow: [
          const BoxShadow(color: Color(0x99000000), blurRadius: 18, offset: Offset(0, 8)),
          if (glow)
            BoxShadow(
                color: Pal.ember.withValues(alpha: 0.22),
                blurRadius: 30,
                spreadRadius: -6),
        ],
      ),
      child: child,
    );
  }
}

/// Square icon button used for the menu's secondary actions.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 58,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: Pal.stoneGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF6A3B33), width: 1.6),
              boxShadow: const [
                BoxShadow(color: Color(0x88000000), blurRadius: 12, offset: Offset(0, 5)),
              ],
            ),
            child: Icon(icon, color: Pal.emberBright, size: size * 0.46),
          ),
          const SizedBox(height: 6),
          Text(label, style: Pal.label(11, color: Pal.muted)),
        ],
      ),
    );
  }
}

/// Icon + amount, used for the wallet and the run summary.
class ResourceChip extends StatelessWidget {
  const ResourceChip({
    super.key,
    required this.image,
    required this.amount,
    this.color = Pal.gold,
    this.compact = false,
  });

  final Widget image;
  final int amount;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 11, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1013),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: compact ? 18 : 22, height: compact ? 18 : 22, child: image),
          const SizedBox(width: 6),
          Text('$amount', style: Pal.number(compact ? 13 : 15, color: color)),
        ],
      ),
    );
  }
}

/// Horizontal meter used for energy and volcano pressure.
class MeterBar extends StatelessWidget {
  const MeterBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 9,
    this.background = const Color(0xAA1A0E10),
  });

  final double value;
  final Color color;
  final double height;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: background,
        child: Align(
          alignment: Alignment.centerLeft,
          // Without heightFactor the childless DecoratedBox collapses to zero
          // height under Align's loose constraints and the fill vanishes.
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.75), color],
                ),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Slow drifting embers behind the menus.
class EmberField extends StatefulWidget {
  const EmberField({super.key, this.count = 26});
  final int count;

  @override
  State<EmberField> createState() => _EmberFieldState();
}

class _EmberFieldState extends State<EmberField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat();
  late final List<_Ember> _embers = List.generate(
    widget.count,
    (i) => _Ember(math.Random(i * 977)),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) =>
              CustomPaint(painter: _EmberPainter(_embers, _c.value), size: Size.infinite),
        ),
      ),
    );
  }
}

class _Ember {
  final double x, speed, drift, size, phase;
  _Ember(math.Random r)
      : x = r.nextDouble(),
        speed = 0.25 + r.nextDouble() * 0.75,
        drift = (r.nextDouble() - 0.5) * 0.16,
        size = 1.2 + r.nextDouble() * 2.8,
        phase = r.nextDouble();
}

class _EmberPainter extends CustomPainter {
  _EmberPainter(this.embers, this.t);
  final List<_Ember> embers;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..blendMode = BlendMode.plus;
    for (final e in embers) {
      final p = (t * e.speed + e.phase) % 1.0;
      final y = size.height * (1.05 - p * 1.1);
      final x = size.width * (e.x + math.sin(p * math.pi * 3) * e.drift);
      final fade = math.sin(p * math.pi).clamp(0.0, 1.0);
      paint.color = Color.lerp(Pal.emberBright, Pal.emberDeep, p)!
          .withValues(alpha: 0.55 * fade);
      canvas.drawCircle(Offset(x, y), e.size, paint);
    }
  }

  @override
  bool shouldRepaint(_EmberPainter old) => old.t != t;
}

/// Fades and lifts its child in. Menus stagger these to enter in sequence.
class RiseIn extends StatefulWidget {
  const RiseIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 24,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> {
  bool _go = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _go = true;
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) setState(() => _go = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _go ? Offset.zero : Offset(0, widget.offset / 100),
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _go ? 1 : 0,
        duration: const Duration(milliseconds: 460),
        child: widget.child,
      ),
    );
  }
}
