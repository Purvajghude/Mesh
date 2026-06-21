import 'package:flutter/material.dart';

/// Single source of truth for Mesh's colour palette.
///
/// Editorial Mono + Pop: a warm paper canvas, near-black ink, and one electric
/// coral accent reserved for energy (matches, CTAs, unlocks). High contrast,
/// magazine-like, illustration-forward — not a generic dark gradient app.
abstract final class AppColors {
  // Canvas — warm paper / cream
  static const Color bg = Color(0xFFF4EEE3);
  static const Color surface = Color(0xFFFBF8F1); // cards
  static const Color surfaceHigh = Color(0xFFEBE4D4); // inputs, chips
  static const Color border = Color(0xFFDCD4C2);

  // Ink — high-contrast near-black used for editorial blocks + text
  static const Color ink = Color(0xFF17130E);

  // Brand pop
  static const Color primary = Color(0xFFEC3A1A); // coral / vermilion
  static const Color primaryBright = Color(0xFFFF5630);
  static const Color primaryDim = Color(0xFFF3A693);

  // Editorial-tuned accents (muted jewels that sit well on cream)
  static const Color pink = Color(0xFFC53D5C);
  static const Color cyan = Color(0xFF177D6E);
  static const Color amber = Color(0xFFC5871F);

  // Semantic
  static const Color success = Color(0xFF2E7D4F);
  static const Color danger = Color(0xFFB3261E);

  // Text
  static const Color text = Color(0xFF17130E);
  static const Color textMuted = Color(0xFF6E6555);
  static const Color textFaint = Color(0xFFA89E8B);

  // Signature gradients — warm pops (kept subtle; the look is mostly flat)
  static const Gradient brandGradient = LinearGradient(
    colors: [primary, Color(0xFFFF6A3D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient matchGradient = LinearGradient(
    colors: [Color(0xFFEC3A1A), Color(0xFFFF6A3D), Color(0xFFC5871F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
