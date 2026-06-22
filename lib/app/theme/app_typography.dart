import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Mesh type scale — Monochrome Editorial.
///
/// Three voices: Archivo (a wide, architectural grotesque) carries every display
/// and heading at heavy weights; Inter keeps body copy quiet and legible; Space
/// Mono is the "data" voice for skill tags, counters, scores, and eyebrows —
/// grounding the app in the builder's world of code.
abstract final class AppTypography {
  static TextTheme textTheme(TextTheme base) {
    final display = GoogleFonts.archivoTextTheme(base);
    final body = GoogleFonts.interTextTheme(base);

    return base.copyWith(
      displayLarge: display.displayLarge?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w900,
        letterSpacing: -2.5,
        height: 0.92,
      ),
      displayMedium: display.displayMedium?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.5,
        height: 0.95,
      ),
      displaySmall: display.displaySmall?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
      ),
      headlineLarge: display.headlineLarge?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: display.titleLarge?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: body.titleMedium?.copyWith(
        color: AppColors.text,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: body.titleSmall?.copyWith(
        color: AppColors.text,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: body.bodyLarge?.copyWith(color: AppColors.text, height: 1.4),
      bodyMedium: body.bodyMedium?.copyWith(
        color: AppColors.textMuted,
        height: 1.4,
      ),
      bodySmall: body.bodySmall?.copyWith(color: AppColors.textMuted),
      labelLarge: body.labelLarge?.copyWith(
        color: AppColors.text,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelMedium: body.labelMedium?.copyWith(color: AppColors.textMuted),
      labelSmall: body.labelSmall?.copyWith(
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }

  /// Space Mono — the "data" voice: skill tags, counters, scores, eyebrows.
  static TextStyle mono({
    double fontSize = 11,
    Color color = AppColors.textFaint,
    FontWeight fontWeight = FontWeight.w400,
    double letterSpacing = 1.4,
  }) => GoogleFonts.spaceMono(
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
  );

  /// Archivo display, for one-off heavy wordmarks outside the [TextTheme].
  static TextStyle display({
    double fontSize = 48,
    Color color = AppColors.ink,
    FontWeight fontWeight = FontWeight.w900,
    double letterSpacing = -2,
  }) => GoogleFonts.archivo(
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: 0.92,
  );
}
