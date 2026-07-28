import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// One sprite inside a packed atlas page.
class Sprite {
  final int page;
  final double x, y, w, h;

  const Sprite(this.page, this.x, this.y, this.w, this.h);

  double get halfW => w / 2;
  double get halfH => h / 2;
  double get aspect => w / h;
}

/// All game sprites packed onto a couple of texture pages.
///
/// Everything is drawn through [SpriteBatch] so that a whole frame costs one
/// draw call per page instead of one per sprite.
class SpriteAtlas {
  final List<ui.Image> pages;
  final Map<String, Sprite> _sprites;
  final Map<String, List<Sprite>> _groups = {};

  SpriteAtlas._(this.pages, this._sprites);

  static Future<SpriteAtlas> load() async {
    final raw = await rootBundle.loadString('assets/atlas/atlas.json');
    final data = json.decode(raw) as Map<String, dynamic>;

    final pages = <ui.Image>[];
    for (var i = 0; i < (data['pages'] as int); i++) {
      final bytes = await rootBundle.load('assets/atlas/atlas_$i.png');
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      pages.add((await codec.getNextFrame()).image);
      codec.dispose();
    }

    final sprites = <String, Sprite>{};
    (data['sprites'] as Map<String, dynamic>).forEach((name, v) {
      final m = v as Map<String, dynamic>;
      sprites[name] = Sprite(m['p'] as int, (m['x'] as num).toDouble(),
          (m['y'] as num).toDouble(), (m['w'] as num).toDouble(),
          (m['h'] as num).toDouble());
    });
    return SpriteAtlas._(pages, sprites);
  }

  Sprite operator [](String name) {
    final s = _sprites[name];
    if (s == null) throw StateError('missing sprite "$name"');
    return s;
  }

  /// Sprite by group and index.
  ///
  /// Atlas keys are zero padded (`effects_vfx/07`), which a call site that
  /// interpolates a number gets wrong for anything under ten.
  Sprite at(String group, int index) =>
      this['$group/${index.toString().padLeft(2, '0')}'];

  /// Every sprite whose name starts with `prefix/`, in index order.
  List<Sprite> group(String prefix) => _groups.putIfAbsent(prefix, () {
        final keys = _sprites.keys.where((k) => k.startsWith('$prefix/')).toList()
          ..sort();
        return [for (final k in keys) _sprites[k]!];
      });

  void dispose() {
    for (final p in pages) {
      p.dispose();
    }
  }
}

/// Collects sprite instances per atlas page and emits one `drawRawAtlas` call
/// for each page. Buffers are reused between frames so a steady frame costs no
/// allocations.
class SpriteBatch {
  final SpriteAtlas atlas;
  final List<Float32List> _xf;
  final List<Float32List> _rect;
  final List<Int32List> _color;
  final List<int> _count;
  final ui.Paint _paint = ui.Paint()..filterQuality = ui.FilterQuality.low;

  SpriteBatch(this.atlas)
      : _xf = List.generate(atlas.pages.length, (_) => Float32List(4 * 256)),
        _rect = List.generate(atlas.pages.length, (_) => Float32List(4 * 256)),
        _color = List.generate(atlas.pages.length, (_) => Int32List(256)),
        _count = List.filled(atlas.pages.length, 0);

  void reset() {
    for (var i = 0; i < _count.length; i++) {
      _count[i] = 0;
    }
  }

  void _grow(int page) {
    final cap = _color[page].length * 2;
    _xf[page] = Float32List(cap * 4)..setRange(0, _count[page] * 4, _xf[page]);
    _rect[page] = Float32List(cap * 4)..setRange(0, _count[page] * 4, _rect[page]);
    _color[page] = Int32List(cap)..setRange(0, _count[page], _color[page]);
  }

  /// Draws [s] centred on ([x],[y]).
  ///
  /// [scale] is uniform because `drawAtlas` transforms cannot squash a sprite;
  /// sprites that need a fixed aspect are baked at that aspect in the atlas.
  void add(
    Sprite s,
    double x,
    double y, {
    double scale = 1.0,
    double rotation = 0.0,
    int color = 0xFFFFFFFF,
    double anchorX = 0.5,
    double anchorY = 0.5,
  }) {
    final page = s.page;
    final n = _count[page];
    if (n >= _color[page].length) _grow(page);

    final scos = math.cos(rotation) * scale;
    final ssin = math.sin(rotation) * scale;
    final ax = s.w * anchorX;
    final ay = s.h * anchorY;

    final i = n * 4;
    _xf[page][i] = scos;
    _xf[page][i + 1] = ssin;
    _xf[page][i + 2] = x - scos * ax + ssin * ay;
    _xf[page][i + 3] = y - ssin * ax - scos * ay;

    _rect[page][i] = s.x;
    _rect[page][i + 1] = s.y;
    _rect[page][i + 2] = s.x + s.w;
    _rect[page][i + 3] = s.y + s.h;

    _color[page][n] = color;
    _count[page] = n + 1;
  }

  void flush(ui.Canvas canvas, {ui.BlendMode blend = ui.BlendMode.modulate}) {
    for (var p = 0; p < atlas.pages.length; p++) {
      final n = _count[p];
      if (n == 0) continue;
      canvas.drawRawAtlas(
        atlas.pages[p],
        Float32List.view(_xf[p].buffer, 0, n * 4),
        Float32List.view(_rect[p].buffer, 0, n * 4),
        Int32List.view(_color[p].buffer, 0, n),
        blend,
        null,
        _paint,
      );
      _count[p] = 0;
    }
  }
}