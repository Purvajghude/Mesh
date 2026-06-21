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
    super.key,
  });

  final AvatarConfig config;
  final double size;
  final double? borderRadius;

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
    );
  }
}
