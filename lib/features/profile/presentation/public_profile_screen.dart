import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/models/avatar_config.dart';
import '../../../data/models/my_skill.dart';
import '../../../shared/widgets/mesh_avatar.dart';
import '../application/profile_providers.dart';
import 'helping_section.dart';

/// Read-only view of another builder's profile — their identity, vibe, and
/// earned/verified skills. Reached from chat, the feed, search, and matches.
class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileByIdProvider(userId));
    final skillsAsync = ref.watch(skillsByIdProvider(userId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load profile: $e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found.'));
          }
          final avatar = AvatarConfig.fromJson(
            profile['avatar_config'] as Map<String, dynamic>?,
          );
          final username = profile['username'] as String? ?? '';
          final displayName = profile['display_name'] as String?;
          final vibe = profile['vibe_statement'] as String?;
          final reputation =
              (profile['reputation'] as num?)?.toDouble() ?? 5.0;
          final collabs = (profile['collab_count'] as num?)?.toInt() ?? 0;
          final helps = (profile['helps_count'] as num?)?.toInt() ?? 0;
          final karma = (profile['help_karma'] as num?)?.toInt() ?? 0;
          final github = profile['github_username'] as String?;
          final name =
              displayName?.isNotEmpty == true ? displayName! : '@$username';

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            children: [
              Center(
                child: Column(
                  children: [
                    MeshAvatar(config: avatar, size: 104),
                    const Gap(16),
                    Text(name,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium),
                    if (displayName?.isNotEmpty == true)
                      Text('@$username',
                          style: AppTypography.mono(
                              fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Gap(22),
              if (vibe?.isNotEmpty == true) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('“',
                        style: AppTypography.display(
                            fontSize: 40, color: AppColors.border)),
                    const Gap(8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          vibe!,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(22),
              ],
              _StatStrip(reputation: reputation, helps: helps, collabs: collabs),
              const Gap(28),
              HelpingSection(
                userId: userId,
                helpsCount: helps,
                karma: karma,
                isMe: false,
              ),
              const Gap(28),
              Text('skills', style: textTheme.titleLarge),
              const Gap(6),
              Container(height: 1, color: AppColors.border),
              const Gap(14),
              skillsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Could not load skills: $e'),
                data: (skills) {
                  if (skills.isEmpty) {
                    return Text('No skills listed yet.',
                        style: textTheme.bodyMedium);
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final s in skills) _SkillChip(skill: s)],
                  );
                },
              ),
              if (github?.isNotEmpty == true) ...[
                const Gap(28),
                Text('proof of skill', style: textTheme.titleLarge),
                const Gap(6),
                Container(height: 1, color: AppColors.border),
                const Gap(14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle,
                          size: 14, color: AppColors.onInk),
                      const Gap(7),
                      Text('GitHub · @$github',
                          style: AppTypography.mono(
                              fontSize: 12, color: AppColors.onInk)),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({
    required this.reputation,
    required this.helps,
    required this.collabs,
  });
  final double reputation;
  final int helps;
  final int collabs;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _StatCell(value: reputation.toStringAsFixed(1), label: 'reputation'),
            const VerticalDivider(
                width: 1, thickness: 1, color: AppColors.border),
            _StatCell(value: '$helps', label: 'helped'),
            const VerticalDivider(
                width: 1, thickness: 1, color: AppColors.border),
            _StatCell(value: '$collabs', label: 'collabs'),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              const Gap(4),
              Text(label,
                  style: AppTypography.mono(fontSize: 9, letterSpacing: 1)),
            ],
          ),
        ),
      );
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.skill});
  final MySkill skill;
  @override
  Widget build(BuildContext context) {
    final compound = skill.isCompound;
    final fg = compound ? AppColors.onInk : AppColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: compound ? AppColors.ink : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (compound) ...[
            Icon(Icons.hub_rounded, size: 13, color: fg),
            const Gap(6),
          ],
          Text(skill.name,
              style:
                  AppTypography.mono(fontSize: 12.5, color: fg, letterSpacing: 0.2)),
          if (skill.verified) ...[
            const Gap(6),
            Icon(Icons.verified, size: 14, color: fg),
          ],
          const Gap(8),
          _Pips(level: skill.level, onDark: compound),
        ],
      ),
    );
  }
}

class _Pips extends StatelessWidget {
  const _Pips({required this.level, this.onDark = false});
  final int level;
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    final on = onDark ? AppColors.onInk : AppColors.ink;
    final off =
        onDark ? AppColors.onInk.withValues(alpha: 0.3) : AppColors.border;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++) ...[
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= level ? on : off,
            ),
          ),
          if (i < 5) const SizedBox(width: 2),
        ],
      ],
    );
  }
}
