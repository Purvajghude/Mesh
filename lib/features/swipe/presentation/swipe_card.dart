import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/models/deck_profile.dart';
import '../../../shared/widgets/mesh_avatar.dart';

/// A single profile card in the swipe deck.
class SwipeCard extends StatelessWidget {
  const SwipeCard({required this.profile, super.key});

  final DeckProfile profile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 28,
            spreadRadius: -14,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Corner registration mark — a quiet print/technical-drawing tell.
          const Positioned(top: 18, right: 18, child: _RegistrationMark()),
          Padding(
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              // Never scrolls (so it can't intercept swipe drags); this just
              // prevents an overflow error when content is taller than the card.
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Gap(8),
                  Center(child: MeshAvatar(config: profile.avatar, size: 148)),
                  const Gap(24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(profile.name, style: textTheme.displaySmall),
                      ),
                      _RepBadge(value: profile.reputation),
                    ],
                  ),
                  if (profile.vibe?.isNotEmpty == true) ...[
                    const Gap(10),
                    Text(
                      profile.vibe!,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const Gap(26),
                  // The real skill-fit score from the recommendation engine
                  // (Task 7) belongs here; until then we show skills honestly.
                  Text(
                    'SKILLS — ${profile.skills.length}',
                    style: AppTypography.mono(
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                  const Gap(12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final skill in profile.skills)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            skill,
                            style: AppTypography.mono(
                              fontSize: 12,
                              color: AppColors.ink,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationMark extends StatelessWidget {
  const _RegistrationMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 14,
      height: 14,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.textFaint, width: 1.5),
            right: BorderSide(color: AppColors.textFaint, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _RepBadge extends StatelessWidget {
  const _RepBadge({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.ink, size: 15),
          const Gap(5),
          Text(
            value.toStringAsFixed(1),
            style: AppTypography.mono(
              fontSize: 12,
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
