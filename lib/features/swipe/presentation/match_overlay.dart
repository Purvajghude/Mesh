import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/models/avatar_config.dart';
import '../../../data/models/deck_profile.dart';
import '../../../shared/widgets/mesh_avatar.dart';
import '../../../shared/widgets/mesh_lattice.dart';

// ── Tweakable knobs ─────────────────────────────────────────────────────────
// Change these and hot-reload (press r) to retune the whole celebration.
const _kDuration = Duration(milliseconds: 3600); // total runtime
const _kGold = Color(0xFFE9B84A); // the colour the sigil inscribes itself in
// The celebration bloom — the one place the grayscale app lets in real colour.
const _kBloom = <Color>[
  Color(0xFFFFD27A), // warm gold core
  Color(0xFFFF7A59), // coral
  Color(0xFF9B5CF6), // violet
  Color(0xFF3E7BFF), // blue edge
];
const _kParticleCount = 30;

/// Shows the full-screen match celebration. Returns true if the user chose to
/// say hi (open chat), false/null if they kept swiping.
///
/// The signature moment, modelled on a gacha 5-star reveal: cut to black, a
/// mesh sigil inscribes itself in light, it bursts into colour, and the two
/// grey avatars bloom into full colour — the only place the app drops its
/// monochrome guard, because a match is the one thing that earns it.
Future<bool?> showMatchOverlay(
  BuildContext context, {
  required AvatarConfig myAvatar,
  required DeckProfile other,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierLabel: 'match',
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, _, _) => _MatchView(myAvatar: myAvatar, other: other),
  );
}

class _MatchView extends StatefulWidget {
  const _MatchView({required this.myAvatar, required this.other});

  final AvatarConfig myAvatar;
  final DeckProfile other;

  @override
  State<_MatchView> createState() => _MatchViewState();
}

class _MatchViewState extends State<_MatchView>
    with SingleTickerProviderStateMixin {
  // One controller is the "clock": it runs 0.0 → 1.0 over _kDuration. Every
  // beat below is just a slice of that timeline.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _kDuration,
  );

  late final List<_Particle> _particles = _makeParticles();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Respect "reduce motion": jump straight to the finished frame.
      if (MediaQuery.of(context).disableAnimations) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Maps the global clock [t] onto a beat that runs from [a] to [b].
  double _seg(double t, double a, double b, [Curve curve = Curves.linear]) =>
      curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  List<_Particle> _makeParticles() {
    final rnd = Random();
    return List.generate(_kParticleCount, (_) {
      return _Particle(
        angle: rnd.nextDouble() * 2 * pi,
        distance: 70 + rnd.nextDouble() * 230,
        size: 1.5 + rnd.nextDouble() * 3.5,
        colorIndex: rnd.nextInt(_kBloom.length),
        twinkle: rnd.nextDouble(),
      );
    });
  }

  void _skip() {
    if (_c.value < 1) _c.animateTo(1, duration: const Duration(milliseconds: 280));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;

        // ── The beats, in order ──────────────────────────────────────────
        final eyebrow = _seg(t, 0.04, 0.16);
        final spark = _seg(t, 0.10, 0.22, Curves.easeOut);
        final sigil = _seg(t, 0.18, 0.50, Curves.easeInOut);
        final sigilNodes = _seg(t, 0.36, 0.50);
        final ring = _seg(t, 0.50, 0.74, Curves.easeOut);
        final sigilOut = _seg(t, 0.52, 0.64);
        final reveal = _seg(t, 0.58, 0.80, Curves.easeOutBack);
        final sat = _seg(t, 0.62, 0.88);
        final title = _seg(t, 0.74, 0.88, Curves.easeOutBack);
        final sub = _seg(t, 0.80, 0.92);
        final skills = _seg(t, 0.83, 0.95);
        final buttons = _seg(t, 0.88, 1.0);
        final particleP = _seg(t, 0.50, 1.0, Curves.easeOut);

        // The colour bloom: flashes up at the burst, then settles to a soft
        // glow behind the reveal.
        final bloom = t < 0.50
            ? 0.0
            : _seg(t, 0.50, 0.60, Curves.easeOut) *
                (1 - 0.5 * _seg(t, 0.60, 1.0));

        return GestureDetector(
          onTap: _skip,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                // Faint grey cosmos that the bloom slowly washes over.
                Positioned.fill(
                  child: Opacity(
                    opacity: (1 - bloom * 0.7).clamp(0.0, 1.0),
                    child: MeshLattice(
                      color: AppColors.onInk.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                // The colour bloom + expanding burst ring.
                Positioned.fill(
                  child: CustomPaint(painter: _FlarePainter(bloom, ring)),
                ),
                // Particles launched at the burst.
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ParticlePainter(_particles, particleP),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),
                        Opacity(
                          opacity: (eyebrow * (1 - sigilOut)).clamp(0.0, 1.0),
                          child: Text(
                            '// CONNECTION FOUND',
                            style: AppTypography.mono(
                              color: AppColors.onInkFaint,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const Gap(28),
                        // The stage: sigil and the avatar reveal share this
                        // space and cross-fade.
                        SizedBox(
                          height: 150,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (spark > 0 && sigilOut < 1)
                                Opacity(
                                  opacity: (1 - sigilOut).clamp(0.0, 1.0),
                                  child: SizedBox(
                                    width: 150,
                                    height: 150,
                                    child: CustomPaint(
                                      painter: _SigilPainter(
                                        spark: spark,
                                        draw: sigil,
                                        nodes: sigilNodes,
                                      ),
                                    ),
                                  ),
                                ),
                              if (reveal > 0)
                                Opacity(
                                  opacity: reveal.clamp(0.0, 1.0),
                                  child: _AvatarPair(
                                    myAvatar: widget.myAvatar,
                                    other: widget.other,
                                    reveal: reveal,
                                    saturation: sat,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Gap(30),
                        Opacity(
                          opacity: title.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.8 + 0.2 * title,
                            child: ShaderMask(
                              shaderCallback: (rect) => const LinearGradient(
                                colors: _kBloom,
                              ).createShader(rect),
                              child: Text(
                                'you mesh.',
                                style: AppTypography.display(
                                  fontSize: 56,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Gap(12),
                        Opacity(
                          opacity: sub.clamp(0.0, 1.0),
                          child: Text(
                            'you and ${widget.other.name} can build together',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.onInkFaint,
                              fontSize: 15,
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (widget.other.skills.isNotEmpty) ...[
                          const Gap(12),
                          Opacity(
                            opacity: skills.clamp(0.0, 1.0),
                            child: Text(
                              'THEY BRING '
                              '${widget.other.skills.take(2).join(" + ").toUpperCase()}',
                              textAlign: TextAlign.center,
                              style: AppTypography.mono(
                                fontSize: 10.5,
                                color: AppColors.onInkFaint,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        IgnorePointer(
                          ignoring: buttons < 1,
                          child: Opacity(
                            opacity: buttons.clamp(0.0, 1.0),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.onInk,
                                      foregroundColor: AppColors.ink,
                                    ),
                                    child: const Text('Say hi'),
                                  ),
                                ),
                                const Gap(8),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text(
                                    'keep swiping',
                                    style: TextStyle(
                                      color: AppColors.onInkFaint,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The two builders revealed side by side, blooming from grey to colour, with a
/// lit bridge between them — the mesh, formed.
class _AvatarPair extends StatelessWidget {
  const _AvatarPair({
    required this.myAvatar,
    required this.other,
    required this.reveal,
    required this.saturation,
  });

  final AvatarConfig myAvatar;
  final DeckProfile other;
  final double reveal;
  final double saturation;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        MeshAvatar(config: myAvatar, size: 104, saturation: saturation),
        SizedBox(
          width: 44,
          height: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: _kBloom),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: _kBloom[1].withValues(alpha: 0.6 * reveal),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
        MeshAvatar(config: other.avatar, size: 104, saturation: saturation),
      ],
    );
  }
}

/// Draws the mesh sigil — a ringed network of nodes — inscribing itself.
class _SigilPainter extends CustomPainter {
  _SigilPainter({required this.spark, required this.draw, required this.nodes});

  /// 0→1 the initial point of light; 0→1 the stroke drawing in; 0→1 node dots.
  final double spark;
  final double draw;
  final double nodes;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);

    // Beat 1: the spark — a bright dot before the sigil draws.
    if (spark > 0 && draw < 0.04) {
      canvas.drawCircle(
        c,
        2 + spark * 4,
        Paint()..color = Colors.white.withValues(alpha: spark),
      );
    }
    if (draw <= 0) return;

    // Build the sigil geometry: an outer ring, six nodes, spokes, a hexagon.
    final outerR = size.width * 0.42;
    final nodeR = size.width * 0.30;
    final nodePts = <Offset>[
      for (var i = 0; i < 6; i++)
        c + Offset.fromDirection(-pi / 2 + i * pi / 3, nodeR),
    ];
    final path = Path()..addOval(Rect.fromCircle(center: c, radius: outerR));
    for (final n in nodePts) {
      path.moveTo(c.dx, c.dy);
      path.lineTo(n.dx, n.dy);
    }
    path.moveTo(nodePts[0].dx, nodePts[0].dy);
    for (var i = 1; i < nodePts.length; i++) {
      path.lineTo(nodePts[i].dx, nodePts[i].dy);
    }
    path.close();

    // A soft glow pass, then a crisp pass — both drawn progressively so the
    // sigil looks inscribed by hand.
    final glow = Paint()
      ..color = _kGold.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final line = Paint()
      ..color = Color.lerp(_kGold, Colors.white, 0.35)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    _drawProgressive(canvas, path, draw, glow);
    _drawProgressive(canvas, path, draw, line);

    // Node dots fade in as the sigil completes.
    if (nodes > 0) {
      final dot = Paint()..color = Colors.white.withValues(alpha: nodes);
      for (final n in nodePts) {
        canvas.drawCircle(n, 2.6, dot);
      }
      canvas.drawCircle(c, 3.2, dot);
    }
  }

  /// Draws [path] up to [progress] of its total length, across all contours.
  void _drawProgressive(Canvas canvas, Path path, double progress, Paint paint) {
    if (progress <= 0) return;
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (s, m) => s + m.length);
    var target = total * progress;
    for (final m in metrics) {
      if (target <= 0) break;
      final take = target < m.length ? target : m.length;
      canvas.drawPath(m.extractPath(0, take), paint);
      target -= take;
    }
  }

  @override
  bool shouldRepaint(_SigilPainter old) =>
      old.spark != spark || old.draw != draw || old.nodes != nodes;
}

/// The colour bloom radiating from the centre, plus the expanding burst ring.
class _FlarePainter extends CustomPainter {
  _FlarePainter(this.bloom, this.ring);

  final double bloom; // 0→1 glow intensity
  final double ring; // 0→1 the ring's expansion

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.longestSide * 0.6;

    if (bloom > 0) {
      final shader = RadialGradient(
        colors: [
          _kBloom[0].withValues(alpha: 0.55 * bloom),
          _kBloom[1].withValues(alpha: 0.32 * bloom),
          _kBloom[2].withValues(alpha: 0.16 * bloom),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: maxR));
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    }

    if (ring > 0 && ring < 1) {
      canvas.drawCircle(
        c,
        ring * maxR * 0.8,
        Paint()
          ..color = Color.lerp(_kGold, Colors.white, 0.4)!
              .withValues(alpha: (1 - ring) * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - ring) + 0.5,
      );
    }
  }

  @override
  bool shouldRepaint(_FlarePainter old) =>
      old.bloom != bloom || old.ring != ring;
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.colorIndex,
    required this.twinkle,
  });

  final double angle;
  final double distance;
  final double size;
  final int colorIndex;
  final double twinkle;
}

/// Coloured motes thrown outward by the burst, drifting and fading.
class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.particles, this.progress);

  final List<_Particle> particles;
  final double progress; // 0→1

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final c = size.center(Offset.zero);
    for (final p in particles) {
      final out = p.distance * progress;
      final pos = c + Offset.fromDirection(p.angle, out);
      // Rise then fall, so motes appear at the burst and fade by the end.
      final alpha = (sin(progress * pi) * (0.6 + 0.4 * p.twinkle)).clamp(0.0, 1.0);
      if (alpha <= 0) continue;
      canvas.drawCircle(
        pos,
        p.size,
        Paint()..color = _kBloom[p.colorIndex].withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
