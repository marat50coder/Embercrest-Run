import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/atlas.dart';

/// Shows one sprite out of the packed atlas as a normal widget.
///
/// Menus need the same art the game draws, and re-reading the original sheets
/// just for icons would double the memory, so they sample the atlas directly.
class SpriteImage extends StatelessWidget {
  const SpriteImage({
    super.key,
    required this.atlas,
    required this.name,
    this.size,
    this.tint,
    this.opacity = 1.0,
  });

  final SpriteAtlas atlas;
  final String name;
  final double? size;
  final Color? tint;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final sprite = atlas[name];
    final child = CustomPaint(
      painter: _SpritePainter(atlas.pages[sprite.page], sprite, tint, opacity),
      size: size == null
          ? Size.infinite
          : Size(size!, size! * sprite.h / sprite.w),
    );
    return size == null ? child : SizedBox(width: size, height: size, child: child);
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.page, this.sprite, this.tint, this.opacity);

  final ui.Image page;
  final Sprite sprite;
  final Color? tint;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = (size.width / sprite.w).clamp(0.0, size.height / sprite.h);
    final w = sprite.w * scale;
    final h = sprite.h * scale;
    final dst = Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);

    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Colors.white.withValues(alpha: opacity);
    if (tint != null) {
      paint.colorFilter = ColorFilter.mode(tint!, BlendMode.srcATop);
    }
    canvas.drawImageRect(
      page,
      Rect.fromLTWH(sprite.x, sprite.y, sprite.w, sprite.h),
      dst,
      paint,
    );
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.sprite != sprite || old.tint != tint || old.opacity != opacity;
}
