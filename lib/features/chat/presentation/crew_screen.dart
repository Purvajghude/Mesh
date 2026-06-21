import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/chat.dart';
import '../../../shared/widgets/mesh_avatar.dart';
import '../application/chat_providers.dart';
import 'chat_screen.dart';

/// Lists the user's matches ("crew") and opens a chat on tap.
class CrewScreen extends ConsumerWidget {
  const CrewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider);

    return matchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load crew: $e')),
      data: (matches) {
        if (matches.isEmpty) {
          return const _EmptyCrew();
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(matchesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: matches.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 88),
            itemBuilder: (context, i) => _CrewTile(match: matches[i]),
          ),
        );
      },
    );
  }
}

class _CrewTile extends StatelessWidget {
  const _CrewTile({required this.match});

  final ChatMatch match;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final preview = match.lastMessage ?? 'you matched — say hi 👋';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: MeshAvatar(config: match.avatar, size: 52),
      title: Text(match.name, style: textTheme.titleMedium),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodyMedium?.copyWith(
          color: match.lastMessage == null
              ? AppColors.primaryBright
              : AppColors.textMuted,
        ),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(match: match)),
      ),
    );
  }
}

class _EmptyCrew extends StatelessWidget {
  const _EmptyCrew();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.diversity_3_rounded,
              size: 56, color: AppColors.textFaint),
          const Gap(16),
          Text('no crew yet', style: Theme.of(context).textTheme.titleMedium),
          const Gap(4),
          Text('swipe to find people to build with',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
