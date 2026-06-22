import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// The signature "mesh" texture: a faint grid of nodes that sits behind hero
/// surfaces. Whisper-quiet by default — it reads as a network substrate, not
/// decoration. Pass an ink-tinted [color] on paper, or a paper-tinted one on ink.
class MeshLattice extends StatelessWidget {
  const MeshLattice({
    this.color,
    this.spacing = 26,
    this.dotRadius = 1.1,
    super.key,
  });

  final Color? color;
  final double spacing;
  final double dotRadius;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _LatticePainter(
          color ?? AppColors.ink.withValues(alpha: 0.05),
          spacing,
          dotRadius,
        ),
      ),
    );
  }
}

class _LatticePainter extends CustomPainter {
  _LatticePainter(this.color, this.spacing, this.dotRadius);

  final Color color;
  final double spacing;
  final double dotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double y = spacing / 2; y < size.height; y += spacing) {
      for (double x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_LatticePainter old) =>
      old.color != color ||
      old.spacing != spacing ||
      old.dotRadius != dotRadius;
}
