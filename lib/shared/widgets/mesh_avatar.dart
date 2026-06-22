import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme/app_colors.dart';
import '../../data/models/avatar_config.dart';

/// Renders a generated DiceBear avatar inside a rounded, bordered tile.
class MeshAvatar extends StatelessWidget {
  const MeshAvatar({
    required this.config,
    this.size = 96,
    this.borderRadius,
    this.saturation = 0,
    super.key,
  });

  final AvatarConfig config;
  final double size;
  final double? borderRadius;

  /// 0 = fully grey (the app's default — avatars are ambient canvas, not a
  /// signal), 1 = full colour. The match celebration animates this 0→1 so the
  /// two builders "bloom" into colour at the moment they connect.
  final double saturation;

  /// Standard saturation matrix: at s=0 every channel collapses to luminance
  /// (grey); at s=1 it's the identity (untouched colour).
  static List<double> _saturationMatrix(double s) {
    const lumR = 0.2126, lumG = 0.7152, lumB = 0.0722;
    final r = (1 - s) * lumR, g = (1 - s) * lumG, b = (1 - s) * lumB;
    return <double>[
      r + s, g, b, 0, 0, //
      r, g + s, b, 0, 0, //
      r, g, b + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.28;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(_saturationMatrix(saturation)),
          child: SvgPicture.network(
            config.svgUrl,
            placeholderBuilder: (_) => const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
