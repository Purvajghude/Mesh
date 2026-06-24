import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/models/deck_profile.dart';
import '../../../shared/widgets/mesh_avatar.dart';

/// A skill chip carrying its earned mastery level — five pips, filled to the
/// skill's level. Reads as a skill-tree node: the more you've earned, the more
/// it lights up. Stays in the monochrome system (level is info, not signal).

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
                  // Why the complementarity engine surfaced this builder — the
                  // "why you're seeing this" signal from the ranking endpoint.
                  if (profile.explanation?.isNotEmpty == true) ...[
                    _WhyChip(text: profile.explanation!),
                    const Gap(22),
                  ],
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
                        _SkillTag(skill: skill),
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

/// The recommendation engine's reason for surfacing this builder. Stays in the
/// monochrome system — it's an intelligence signal, drawn as an inked callout
/// with a left accent rule, not decoration.
class _WhyChip extends StatelessWidget {
  const _WhyChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceHigh,
        border: Border(left: BorderSide(color: AppColors.ink, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_outlined, size: 12, color: AppColors.ink),
              const Gap(6),
              Text(
                'WHY YOU MESH',
                style: AppTypography.mono(
                  fontSize: 9,
                  letterSpacing: 2,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const Gap(7),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              color: AppColors.ink,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillTag extends StatelessWidget {
  const _SkillTag({required this.skill});

  final DeckSkill skill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            skill.name,
            style: AppTypography.mono(
              fontSize: 12,
              color: AppColors.ink,
              letterSpacing: 0.3,
            ),
          ),
          const Gap(8),
          _LevelPips(level: skill.level),
        ],
      ),
    );
  }
}

/// Five pips, filled up to [level] — the skill's earned mastery.
class _LevelPips extends StatelessWidget {
  const _LevelPips({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++) ...[
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= level ? AppColors.ink : AppColors.border,
            ),
          ),
          if (i < 5) const SizedBox(width: 2),
        ],
      ],
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
