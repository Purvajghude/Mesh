import 'package:flutter/material.dart';

/// Single source of truth for Mesh's colour palette.
///
/// Monochrome Editorial: warm paper, near-black ink, and a ramp of warm greys —
/// nothing else. There is no brand accent hue; emphasis comes from ink fills and
/// inversion, never colour. The only place colour is permitted is functional
/// error/success feedback, used sparingly and never as decoration.
abstract final class AppColors {
  // Canvas — warm paper / greys
  static const Color bg = Color(0xFFEDEAE3); // paper
  static const Color surface = Color(0xFFF7F5F0); // snow — cards
  static const Color surfaceHigh = Color(0xFFE4E0D6); // inputs, chips, fills
  static const Color border = Color(0xFFD6D0C4); // hairline / rules

  // Ink — the single "accent" in a monochrome system
  static const Color ink = Color(0xFF15130F);
  static const Color inkSoft = Color(0xFF2A2620); // borders/strokes on ink

  // Text
  static const Color text = Color(0xFF15130F);
  static const Color textMuted = Color(0xFF57534A); // graphite
  static const Color textFaint = Color(0xFF98917F); // meta / captions

  // Text/strokes on ink surfaces (inverted blocks, the match moment)
  static const Color onInk = Color(0xFFEDEAE3); // paper on ink
  static const Color onInkFaint = Color(0xFFB8B1A2); // faint on ink

  // Functional only — never decorative. Deep, desaturated so they sit in the
  // monochrome world rather than reading as a brand colour.
  static const Color success = Color(0xFF2E6B4F); // deep pine
  static const Color danger = Color(0xFF8A2D22); // deep brick (errors)
}
