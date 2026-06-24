import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/models/help_stat.dart';
import '../application/profile_providers.dart';
import 'leaderboard_screen.dart';

/// "Helping" — a builder's earned reputation as a helper: how many people they've
/// unblocked and the skills they're proven helpful in. The status surface that
/// makes helping worth doing.
class HelpingSection extends ConsumerWidget {
  const HelpingSection({
    required this.userId,
    required this.helpsCount,
    required this.karma,
    required this.isMe,
    super.key,
  });

  final String userId;
  final int helpsCount;
  final int karma;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(helpProfileProvider(userId));
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('helping', style: textTheme.titleLarge),
            const Spacer(),
            InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LeaderboardScreen(),
              )),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events_outlined,
                        size: 15, color: AppColors.ink),
                    const Gap(4),
                    Text('leaderboard',
                        style: AppTypography.mono(
                            color: AppColors.ink, letterSpacing: 0.3)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const Gap(6),
        Container(height: 1, color: AppColors.border),
        const Gap(12),
        if (helpsCount == 0)
          Text(
            isMe
                ? "you haven't helped anyone yet — answer an ask in the feed."
                : "hasn't helped anyone yet.",
            style: textTheme.bodyMedium,
          )
        else ...[
          Row(
            children: [
              const Icon(Icons.volunteer_activism_rounded,
                  size: 18, color: AppColors.ink),
              const Gap(8),
              Text(
                '$helpsCount ${helpsCount == 1 ? "builder" : "builders"} helped',
                style: textTheme.titleSmall,
              ),
              const Gap(10),
              Text('· $karma karma',
                  style: AppTypography.mono(color: AppColors.textMuted)),
            ],
          ),
          statsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (stats) {
              if (stats.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final s in stats) _HelpChip(stat: s)],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _HelpChip extends StatelessWidget {
  const _HelpChip({required this.stat});
  final HelpStat stat;

  @override
  Widget build(BuildContext context) {
    final expert = stat.expert;
    final fg = expert ? AppColors.onInk : AppColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: expert ? AppColors.ink : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (expert) ...[
            Icon(Icons.star_rounded, size: 13, color: fg),
            const Gap(5),
            Text('Expert · ',
                style: AppTypography.mono(color: fg, letterSpacing: 0.2)),
          ],
          Text(stat.skillName,
              style: AppTypography.mono(
                  fontSize: 12, color: fg, letterSpacing: 0.2)),
          const Gap(8),
          Text('${stat.karma}',
              style: AppTypography.mono(
                  fontSize: 10.5,
                  color: expert ? AppColors.onInkFaint : AppColors.textMuted)),
        ],
      ),
    );
  }
}
