import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../shared/widgets/mesh_avatar.dart';
import '../application/profile_providers.dart';
import 'public_profile_screen.dart';

/// Top helpers — the status board that makes helping a game worth playing.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(topHelpersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('top helpers')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load leaderboard: $e')),
        data: (helpers) {
          if (helpers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'no helpers ranked yet — answer an ask and be the first.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: helpers.length,
            separatorBuilder: (_, _) => const Gap(8),
            itemBuilder: (context, i) {
              final h = helpers[i];
              final rank = i + 1;
              return InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PublicProfileScreen(userId: h.profileId),
                )),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: rank <= 3 ? AppColors.ink : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '$rank',
                          textAlign: TextAlign.center,
                          style: AppTypography.display(
                            fontSize: rank <= 3 ? 22 : 16,
                            color: rank <= 3 ? AppColors.ink : AppColors.textFaint,
                          ),
                        ),
                      ),
                      const Gap(10),
                      MeshAvatar(config: h.avatar, size: 38),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h.name,
                                style: Theme.of(context).textTheme.titleSmall),
                            Text('${h.helps} builders helped',
                                style: AppTypography.mono(fontSize: 10)),
                          ],
                        ),
                      ),
                      Text('${h.karma}',
                          style: Theme.of(context).textTheme.titleLarge),
                      const Gap(4),
                      Text('karma',
                          style: AppTypography.mono(
                              fontSize: 8.5, letterSpacing: 1)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
