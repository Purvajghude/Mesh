import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/feed_post.dart';
import '../../../shared/widgets/mesh_avatar.dart';
import '../application/feed_providers.dart';
import 'compose_post_sheet.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedChannelProvider);
    final feedAsync = ref.watch(feedProvider);

    return Stack(
      children: [
        Column(
          children: [
            _ChannelBar(selected: selected),
            Expanded(
              child: feedAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Could not load feed: $e')),
                data: (posts) {
                  if (posts.isEmpty) {
                    return const Center(child: Text('nothing here yet — post something!'));
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(feedProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: posts.length,
                      itemBuilder: (context, i) => _PostCard(post: posts[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            onPressed: () => showComposePostSheet(context, ref),
            backgroundColor: AppColors.ink,
            child: const Icon(Icons.edit_rounded, color: AppColors.onInk),
          ),
        ),
      ],
    );
  }
}

class _ChannelBar extends ConsumerWidget {
  const _ChannelBar({required this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <String?>[null, ...feedChannels];
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, _) => const Gap(8),
        itemBuilder: (context, i) {
          final channel = items[i];
          final isSel = channel == selected;
          return GestureDetector(
            onTap: () =>
                ref.read(selectedChannelProvider.notifier).select(channel),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSel ? AppColors.ink : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSel ? AppColors.ink : AppColors.border,
                ),
              ),
              child: Text(
                channel == null ? 'all' : '#$channel',
                style: TextStyle(
                  color: isSel ? AppColors.onInk : AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PostCard extends ConsumerStatefulWidget {
  const _PostCard({required this.post});

  final FeedPost post;

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  late bool _upvoted = widget.post.upvoted;
  late int _count = widget.post.upvotes;

  Future<void> _toggle() async {
    // Optimistic update.
    setState(() {
      _upvoted = !_upvoted;
      _count += _upvoted ? 1 : -1;
    });
    try {
      final newState =
          await ref.read(feedRepositoryProvider).toggleUpvote(widget.post.id);
      if (mounted && newState != _upvoted) {
        setState(() {
          _upvoted = newState;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _upvoted = !_upvoted;
          _count += _upvoted ? 1 : -1;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MeshAvatar(config: post.avatar, size: 40),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.authorName, style: textTheme.titleSmall),
                    Row(
                      children: [
                        Text('#${post.channel}',
                            style: AppTypography.mono(
                                fontSize: 10.5, color: AppColors.ink)),
                        Text('  ·  ${_ago(post.createdAt)}',
                            style: AppTypography.mono(fontSize: 10.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(12),
          Text(post.body, style: textTheme.bodyLarge?.copyWith(height: 1.35)),
          const Gap(12),
          GestureDetector(
            onTap: _toggle,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _upvoted
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_upward_outlined,
                  size: 18,
                  color: _upvoted ? AppColors.ink : AppColors.textMuted,
                ),
                const Gap(6),
                Text(
                  '$_count',
                  style: TextStyle(
                    color: _upvoted ? AppColors.ink : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  return '${d.inDays}d';
}
