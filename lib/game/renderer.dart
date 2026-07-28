import 'dart:math' as math;
import 'dart:ui' as ui;

// Flutter's physics layer also exports a `Simulation`; the game's own class is
// the one meant here.
import 'package:flutter/material.dart' hide Simulation;
import 'package:flutter/services.dart' show rootBundle;

import '../core/atlas.dart';
import 'config.dart';
import 'simulation.dart';

/// Camera framing: how many world units fit vertically on screen.
const double kViewHeight = 680;

/// Draws a frame of the run.
///
/// Every sprite goes through one [SpriteBatch], so the whole scene costs one
/// `drawAtlas` per atlas page regardless of how much is on screen. Layers are
/// flushed in order where sorting matters.
class GameRenderer {
  GameRenderer(this.atlas) : _batch = SpriteBatch(atlas);

  final SpriteAtlas atlas;
  final SpriteBatch _batch;
  final Map<String, TextPainter> _textCache = {};

  // Shaders are expensive to build, so every one of them is made once and then
  // re-aimed with canvas transforms or a colour filter instead of rebuilt.
  final Paint _bgPaint = Paint();
  final Paint _bgTint = Paint()..blendMode = BlendMode.overlay;
  final Paint _bgShade = Paint()..color = const Color(0x1A100608);
  final Paint _glowPaint = Paint()
    ..shader = _unitGlow(const [Color(0x33FFC24A), Color(0x11FF7A18), Color(0x00000000)],
        const [0.0, 0.6, 1.0]);
  final Paint _heatPaint = Paint()
    ..shader = _unitGlow(const [Color(0x88FFB13C), Color(0x00FF7A18)], null);
  final Paint _vignette = Paint();
  final Paint _danger = Paint();
  final Paint _flashPaint = Paint()..blendMode = BlendMode.plus;
  Size _overlaySize = Size.zero;

  ui.Image? background;
  ui.Image? _bgShaderFor;

  /// A glow centred on the origin with radius 1, so a translate+scale aims it.
  static ui.Shader _unitGlow(List<Color> colors, List<double>? stops) =>
      ui.Gradient.radial(Offset.zero, 1, colors, stops);

  late final List<Sprite> _road = atlas.group('road');
  late final List<Sprite> _roadBreak = atlas.group('roadbreak');

  void paint(Canvas canvas, Size size, Simulation sim, double camX, double camY) {
    final scale = size.height / kViewHeight;
    final shake = sim.shakeOffset;

    canvas.save();
    canvas.translate(size.width / 2 + shake.dx, size.height / 2 + shake.dy);
    canvas.scale(scale);
    canvas.translate(-camX, -camY);

    final halfW = size.width / (2 * scale);
    final halfH = size.height / (2 * scale);
    final view = Rect.fromLTRB(
        camX - halfW - 120, camY - halfH - 120, camX + halfW + 120, camY + halfH + 120);

    _drawBackground(canvas, view, sim);
    sim.collectVisible(view.left, view.top, view.right, view.bottom);

    _drawGround(canvas, sim, view);
    _drawCrest(canvas, sim, view);
    _drawEntities(canvas, sim, view);
    _drawHero(canvas, sim);
    _drawParticles(canvas, sim);
    _drawFloats(canvas, sim, scale);

    canvas.restore();
    _drawOverlay(canvas, size, sim);
  }

  // ------------------------------------------------------------ background
  void _drawBackground(Canvas canvas, Rect view, Simulation sim) {
    final image = background;
    if (image == null) {
      canvas.drawRect(view, Paint()..color = const Color(0xFF1A0C09));
      return;
    }
    // Mirrored tiling hides the seams of a texture that is not tileable, and
    // the texture is drawn large so the repeat is hard to read.
    if (_bgShaderFor != image) {
      const texScale = 1.35;
      _bgPaint.shader = ui.ImageShader(
        image,
        TileMode.mirror,
        TileMode.mirror,
        Matrix4.diagonal3Values(texScale, texScale, 1).storage,
      );
      _bgShaderFor = image;
    }
    canvas.drawRect(view, _bgPaint);

    _bgTint.color = sim.biome.tint.withValues(alpha: 0.20);
    canvas.drawRect(view, _bgTint);
    // Just enough to sit the crest and pickups forward of the ground.
    canvas.drawRect(view, _bgShade);
  }

  // ------------------------------------------------------------ ground pass
  void _drawGround(Canvas canvas, Simulation sim, Rect view) {
    for (final chunk in sim.visibleChunks) {
      for (final d in chunk.decor) {
        if (!view.contains(Offset(d.x, d.y))) continue;
        _batch.add(d.sprite, d.x, d.y,
            scale: d.scale, rotation: d.rotation, color: d.color);
      }
    }
    _batch.flush(canvas);

    // Currents read as a soft drifting swirl under the surface.
    for (final chunk in sim.visibleChunks) {
      for (final c in chunk.currents) {
        if (!view.contains(Offset(c.x, c.y))) continue;
        final t = sim.time * 0.6 + c.x * 0.01;
        canvas.save();
        canvas.translate(c.x, c.y);
        canvas.scale(c.radius);
        canvas.drawCircle(Offset.zero, 1, _glowPaint);
        canvas.restore();
        for (var i = 0; i < 4; i++) {
          final a = c.angle + math.sin(t + i) * 0.35;
          final r = c.radius * (0.25 + i * 0.18);
          _batch.add(
            atlas.at('effects_vfx', 26 - (i % 2)),
            c.x + math.cos(a) * r,
            c.y + math.sin(a) * r,
            scale: 0.35 * c.strength,
            rotation: a,
            color: 0x55FFB060,
          );
        }
      }
    }
    _batch.flush(canvas, blend: BlendMode.plus);
  }

  // ------------------------------------------------------------ crest
  Sprite _segmentSprite(RoadSegment s) {
    if (s.crystallized) return _road[7];
    final t = s.t;
    final magma = s.magma;
    if (magma != null && t < 0.55) {
      return atlas[MagmaInfo.of(magma).roadSprite];
    }
    if (t < 0.16) return _road[1];
    if (t < 0.34) return _road[0];
    if (t < 0.52) return _road[2];
    if (t < 0.68) return _road[4];
    if (t < 0.78) return _road[5];
    final k = ((t - 0.78) / 0.22 * 8).clamp(0, 8).toInt();
    return _roadBreak[3 + k];
  }

  void _drawCrest(Canvas canvas, Simulation sim, Rect view) {
    final scale = Simulation.roadWidth / 112.0;
    for (final s in sim.road) {
      if (s.x < view.left || s.x > view.right || s.y < view.top || s.y > view.bottom) {
        continue;
      }
      final sprite = _segmentSprite(s);
      // The capsule art points up, the segment heading points along +x.
      final alpha = s.crystallized ? 1.0 : (1.0 - (s.t - 0.9) / 0.1).clamp(0.35, 1.0);
      _batch.add(sprite, s.x, s.y,
          scale: scale,
          rotation: s.angle + math.pi / 2,
          color: _white(alpha));
    }
    _batch.flush(canvas);
  }

  // ------------------------------------------------------------ entities
  void _drawEntities(Canvas canvas, Simulation sim, Rect view) {
    final t = sim.time;
    for (final chunk in sim.visibleChunks) {
      for (final a in chunk.altars) {
        if (a.taken || !view.contains(Offset(a.x, a.y))) continue;
        final pulse = 1 + math.sin(t * 2 + a.x) * 0.04;
        _batch.add(atlas[Artifacts.all[a.index]], a.x, a.y, scale: 0.72 * pulse);
      }
      for (final c in chunk.cores) {
        if (c.taken || !view.contains(Offset(c.x, c.y))) continue;
        final info = MagmaInfo.of(c.type);
        final pulse = 1 + math.sin(t * 3 + c.x * 0.01) * 0.07;
        _batch.add(atlas[info.coreSprite], c.x, c.y, scale: 0.62 * pulse);
      }
      for (final o in chunk.obstacles) {
        if (o.destroyed || !view.contains(Offset(o.x, o.y))) continue;
        _batch.add(o.sprite, o.x, o.y, scale: o.scale);
      }
      for (final cr in chunk.creatures) {
        if (cr.used) continue;
        final cx = cr.drawX(t), cy = cr.drawY(t);
        if (!view.contains(Offset(cx, cy))) continue;
        _batch.add(cr.sprite, cx, cy,
            scale: cr.scale * (1 + math.sin(t * 4 + cr.phase) * 0.05),
            color: cr.friendly ? 0xFFFFFFFF : 0xFFFFD0D0);
      }
      for (final p in chunk.pickups) {
        if (p.taken) continue;
        if (!view.contains(Offset(p.drawX, p.drawY))) continue;
        final bob = math.sin(t * 2.6 + p.phase) * 4;
        _batch.add(p.sprite, p.drawX, p.drawY + bob, scale: 0.46);
      }
    }
    _batch.flush(canvas);

    for (final e in sim.eruptions) {
      final age = sim.time - e.born;
      final frame = (age / 2.6 * 4).clamp(0, 4).toInt();
      final grow = 0.5 + age * 0.5;
      _batch.add(atlas.at('effects_vfx', 18 + frame), e.x, e.y,
          scale: grow, color: _white((1 - age / 2.6).clamp(0.0, 1.0)));
    }
    _batch.flush(canvas, blend: BlendMode.plus);
  }

  // ------------------------------------------------------------ hero
  void _drawHero(Canvas canvas, Simulation sim) {
    if (sim.state == RunState.over) return;
    final skin = atlas[Skin.all[heroSkin].sprite];
    final bob = math.sin(sim.time * 9) * 2.4;

    // Heat pool under the feet, so the hero never looks pasted on.
    canvas.save();
    canvas.translate(sim.heroX, sim.heroY + 16);
    canvas.scale(46);
    canvas.drawCircle(Offset.zero, 1, _heatPaint);
    canvas.restore();

    final tint = sim.activeMagma != null
        ? MagmaInfo.of(sim.activeMagma!).color
        : Colors.white;
    _batch.add(skin, sim.heroX, sim.heroY + bob,
        scale: 86 / skin.h, color: _tint(tint, 1.0));

    // A small flame arc marks which way the crest will grow next.
    _batch.add(
      atlas['effects_vfx/25'],
      sim.heroX + math.cos(sim.heading) * 60,
      sim.heroY + math.sin(sim.heading) * 60,
      scale: 0.34,
      rotation: sim.heading + math.pi / 2,
      color: 0xCCFFC24A,
    );
    _batch.flush(canvas);
  }

  int heroSkin = 0;

  // ------------------------------------------------------------ fx
  void _drawParticles(Canvas canvas, Simulation sim) {
    for (final p in sim.particles) {
      final k = (p.life / p.maxLife).clamp(0.0, 1.0);
      _batch.add(p.sprite, p.x, p.y,
          scale: p.scale,
          rotation: p.rotation,
          color: (p.color & 0x00FFFFFF) | ((255 * k).toInt() << 24));
    }
    _batch.flush(canvas, blend: BlendMode.plus);
  }

  void _drawFloats(Canvas canvas, Simulation sim, double scale) {
    for (final f in sim.floats) {
      // Fading through a saveLayer costs an offscreen pass per label, so the
      // alpha is baked into the text style and quantised to keep the cache small.
      final k = (f.life / 0.9).clamp(0.0, 1.0);
      final step = (k * 6).round();
      if (step == 0) continue;
      final tp = _text(f.text, f.color, step / 6);
      canvas.save();
      canvas.translate(f.x, f.y);
      canvas.scale(1 / scale * 0.9);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  TextPainter _text(String value, int color, double opacity) {
    final key = '$value|$color|$opacity';
    return _textCache.putIfAbsent(key, () {
      final tp = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: Color(color).withValues(alpha: opacity),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Colors.black.withValues(alpha: opacity), blurRadius: 4),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp;
    });
  }

  // ------------------------------------------------------------ overlay
  void _drawOverlay(Canvas canvas, Size size, Simulation sim) {
    final rect = Offset.zero & size;
    if (_overlaySize != size) {
      _overlaySize = size;
      // White ramps whose alpha is the only thing that matters; the colour
      // comes from a filter, so one shader per size covers every tint.
      _vignette.shader = ui.Gradient.radial(rect.center, size.width * 0.78,
          const [Color(0x00FFFFFF), Color(0xFFFFFFFF)], const [0.62, 1.0]);
      _danger.shader = ui.Gradient.radial(rect.center, size.width * 0.8,
          const [Color(0x00FFFFFF), Color(0xFFFFFFFF)], const [0.4, 1.0]);
    }

    // Vignette keeps the eye on the crest and hides the tiling at the edges.
    _vignette.colorFilter =
        const ColorFilter.mode(Color(0x8A000000), BlendMode.srcIn);
    canvas.drawRect(rect, _vignette);

    if (sim.energyFraction < 0.25) {
      final pulse = (0.5 + math.sin(sim.time * 8) * 0.5) *
          (1 - sim.energyFraction / 0.25);
      _danger.colorFilter = ColorFilter.mode(
          Color.fromRGBO(255, 40, 20, 0.45 * pulse), BlendMode.srcIn);
      canvas.drawRect(rect, _danger);
    }

    if (sim.flash > 0) {
      _flashPaint.color =
          Color(sim.flashColor).withValues(alpha: sim.flash * 0.35);
      canvas.drawRect(rect, _flashPaint);
    }
  }

  static int _white(double alpha) =>
      ((alpha.clamp(0.0, 1.0) * 255).toInt() << 24) | 0x00FFFFFF;

  static int _tint(Color c, double alpha) {
    final a = (alpha.clamp(0.0, 1.0) * 255).toInt();
    final blend = Color.lerp(Colors.white, c, 0.35)!;
    return (a << 24) |
        ((blend.r * 255).round() << 16) |
        ((blend.g * 255).round() << 8) |
        (blend.b * 255).round();
  }

  void dispose() {
    background?.dispose();
    background = null;
  }
}

/// Keeps at most a couple of biome backgrounds decoded at a time.
class BackgroundCache {
  final Map<String, ui.Image> _images = {};
  final List<String> _order = [];

  Future<ui.Image> get(String assetPath) async {
    final cached = _images[assetPath];
    if (cached != null) return cached;

    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final image = (await codec.getNextFrame()).image;
    codec.dispose();

    _images[assetPath] = image;
    _order.add(assetPath);
    while (_order.length > 2) {
      _images.remove(_order.removeAt(0))?.dispose();
    }
    return image;
  }

  void dispose() {
    for (final i in _images.values) {
      i.dispose();
    }
    _images.clear();
    _order.clear();
  }
}
