import 'package:flutter/material.dart';

/// Colours and text styles shared by every screen.
class Pal {
  static const ash = Color(0xFF120A0C);
  static const basalt = Color(0xFF1D1216);
  static const basaltLight = Color(0xFF2C1C21);
  static const ember = Color(0xFFFF7A18);
  static const emberBright = Color(0xFFFFB43C);
  static const emberDeep = Color(0xFFD8380B);
  static const lava = Color(0xFFFF4D1C);
  static const gold = Color(0xFFFFD166);
  static const crystal = Color(0xFF6FD6FF);
  static const obsidian = Color(0xFF9B6BFF);
  static const bone = Color(0xFFF6E8DC);
  static const muted = Color(0xFFB49A93);
  static const danger = Color(0xFFFF3B30);

  static const emberGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFC24A), Color(0xFFFF7A18), Color(0xFFD8380B)],
    stops: [0.0, 0.55, 1.0],
  );

  static const stoneGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF3A272C), Color(0xFF1E1317)],
  );

  static TextStyle title(double size) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: bone,
        letterSpacing: 1.6,
        height: 1.05,
        shadows: const [
          Shadow(color: Color(0xAA000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      );

  static TextStyle label(double size, {Color color = bone, FontWeight w = FontWeight.w700}) =>
      TextStyle(
        fontSize: size,
        fontWeight: w,
        color: color,
        letterSpacing: 0.6,
        shadows: const [
          Shadow(color: Color(0x99000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      );

  static TextStyle number(double size, {Color color = bone}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: 0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
        shadows: const [
          Shadow(color: Color(0xAA000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      );
}
