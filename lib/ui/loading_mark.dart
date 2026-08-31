import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/palette.dart';

/// Continuous loading caption + bar. The fill creeps toward ~92% without
/// pausing, then runs to 100% only once [ready] is true.
class LoadingMark extends StatefulWidget {
  const LoadingMark({
    super.key,
    required this.ready,
    this.onFilled,
  });

  final bool ready;
  final VoidCallback? onFilled;

  @override
  State<LoadingMark> createState() => _LoadingMarkState();
}

class _LoadingMarkState extends State<LoadingMark>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final Stopwatch _elapsed = Stopwatch();
  double _value = 0;
  bool _finishing = false;
  bool _signaled = false;
  Duration _finishStarted = Duration.zero;
  double _finishFrom = 0;

  static const double _ceiling = 0.92;
  static const double _tauSeconds = 2.6;
  static const int _finishMs = 380;

  @override
  void initState() {
    super.initState();
    _elapsed.start();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(LoadingMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready && !oldWidget.ready) {
      _beginFinish();
    }
  }

  void _beginFinish() {
    if (_finishing) return;
    _finishing = true;
    _finishFrom = _value;
    _finishStarted = _elapsed.elapsed;
  }

  void _onTick(Duration _) {
    if (!mounted) return;
    if (!_finishing && widget.ready) {
      _beginFinish();
    }
    final seconds = _elapsed.elapsedMilliseconds / 1000.0;
    double next;
    if (_finishing) {
      final u = ((_elapsed.elapsed - _finishStarted).inMilliseconds / _finishMs)
          .clamp(0.0, 1.0);
      final eased = Curves.easeOutCubic.transform(u);
      next = _finishFrom + (1 - _finishFrom) * eased;
      if (u >= 1 && !_signaled) {
        _signaled = true;
        _ticker.stop();
        final filled = widget.onFilled;
        if (filled != null) {
          SchedulerBinding.instance.addPostFrameCallback((_) => filled());
        }
      }
    } else {
      next = _ceiling * (1 - math.exp(-seconds / _tauSeconds));
    }
    if ((next - _value).abs() > 0.001 || _finishing) {
      setState(() => _value = next);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Text(
              'loading',
              style: Pal.label(28, color: Colors.black, w: FontWeight.w900).copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 5
                  ..color = Colors.black,
              ),
            ),
            Text(
              'loading',
              style: Pal.label(28, color: Pal.bone, w: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _FillBar(value: _value),
      ],
    );
  }
}

class _FillBar extends StatelessWidget {
  const _FillBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: const Color(0xCC1A0E10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Pal.basaltLight, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value <= 0 ? 0.001 : value.clamp(0.0, 1.0),
              heightFactor: 1,
              child: const ColoredBox(color: Pal.gold),
            ),
          ),
        ),
      ),
    );
  }
}
