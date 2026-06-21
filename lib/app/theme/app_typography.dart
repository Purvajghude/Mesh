import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Mesh type scale — Editorial Mono + Pop.
///
/// Fraunces (a characterful variable serif) drives the big magazine-style
/// display + headings; Inter keeps body copy crisp and legible.
abstract final class AppTypography {
  static TextTheme textTheme(TextTheme base) {
    final display = GoogleFonts.frauncesTextTheme(base);
    final body = GoogleFonts.interTextTheme(base);

    return base.copyWith(
      displayLarge: display.displayLarge?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        height: 0.95,
      ),
      displayMedium: display.displayMedium?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
      ),
      displaySmall: display.displaySmall?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineLarge: display.headlineLarge?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: display.titleLarge?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: body.titleMedium?.copyWith(
        color: AppColors.text,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: body.titleSmall?.copyWith(
        color: AppColors.text,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: body.bodyLarge?.copyWith(color: AppColors.text),
      bodyMedium: body.bodyMedium?.copyWith(color: AppColors.textMuted),
      bodySmall: body.bodySmall?.copyWith(color: AppColors.textMuted),
      labelLarge: body.labelLarge?.copyWith(
        color: AppColors.text,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelSmall: body.labelSmall?.copyWith(color: AppColors.textMuted),
    );
  }
}
