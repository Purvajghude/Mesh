import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/avatar_config.dart';
import '../../../data/models/deck_profile.dart';
import '../../../shared/widgets/gradient_text.dart';
import '../../../shared/widgets/mesh_avatar.dart';

/// Shows the full-screen match celebration. Returns true if the user chose to
/// say hi (open chat), false/null if they kept swiping.
Future<bool?> showMatchOverlay(
  BuildContext context, {
  required AvatarConfig myAvatar,
  required DeckProfile other,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierLabel: 'match',
    barrierColor: Colors.black.withValues(alpha: 0.86),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (_, _, _) => _MatchView(myAvatar: myAvatar, other: other),
  );
}

class _MatchView extends StatelessWidget {
  const _MatchView({required this.myAvatar, required this.other});

  final AvatarConfig myAvatar;
  final DeckProfile other;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Radial brand glow.
          Center(
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 200,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms).scale(
                  begin: const Offset(0.6, 0.6),
                  curve: Curves.easeOut,
                ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  GradientText(
                    "it's a mesh!",
                    gradient: AppColors.matchGradient,
                    style: textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut)
                      .then()
                      .shimmer(duration: 1200.ms, color: Colors.white24),
                  const Gap(40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MeshAvatar(config: myAvatar, size: 120)
                          .animate()
                          .slideX(begin: -2, duration: 600.ms, curve: Curves.easeOutBack)
                          .fadeIn(),
                      Transform.translate(
                        offset: const Offset(0, 0),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.bolt_rounded,
                              color: AppColors.amber, size: 40),
                        ),
                      ).animate(delay: 500.ms).fadeIn().scale(
                            begin: const Offset(0, 0),
                            curve: Curves.elasticOut,
                          ),
                      MeshAvatar(config: other.avatar, size: 120)
                          .animate()
                          .slideX(begin: 2, duration: 600.ms, curve: Curves.easeOutBack)
                          .fadeIn(),
                    ],
                  ),
                  const Gap(28),
                  Text(
                    'you and ${other.name} can build together',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ).animate(delay: 700.ms).fadeIn(),
                  if (other.skills.isNotEmpty) ...[
                    const Gap(8),
                    Text(
                      'they bring ${other.skills.take(2).join(" + ")}',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium,
                    ).animate(delay: 850.ms).fadeIn(),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Say hi 👋'),
                    ),
                  ).animate(delay: 1000.ms).fadeIn().slideY(begin: 0.5),
                  const Gap(8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'keep swiping',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ).animate(delay: 1100.ms).fadeIn(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
