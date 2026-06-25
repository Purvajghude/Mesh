import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/feed_post.dart';
import '../../../data/services/supabase_service.dart';
import '../../../shared/widgets/mesh_avatar.dart';
import '../../profile/presentation/public_profile_screen.dart';
import '../application/feed_providers.dart';
import 'compose_post_sheet.dart';
import 'post_detail_screen.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(feedFilterProvider);
    final feedAsync = ref.watch(feedProvider);

    return Stack(
      children: [
        Column(
          children: [
            _KindFilterBar(selected: filter),
            Expanded(
              child: feedAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Could not load feed: $e')),
                data: (posts) {
                  final shown = filter == null
                      ? posts
                      : [for (final p in posts) if (p.kind == filter) p];
                  // The "asks for you" strip: open asks matching your proven
                  // skills. Shown on the All and Asks views.
                  final forMe = ref.watch(asksForMeProvider).value ?? const [];
                  final showStrip =
                      (filter == null || filter == FeedKind.ask) && forMe.isNotEmpty;

                  Future<void> refresh() async {
                    ref.invalidate(feedProvider);
                    ref.invalidate(asksForMeProvider);
                  }

                  if (shown.isEmpty && !showStrip) {
                    return RefreshIndicator(
                      onRefresh: refresh,
                      child: ListView(
                        children: [
                          const Gap(120),
                          Center(
                            child: Text(
                              filter == FeedKind.ask
                                  ? 'no open asks — be the first to ask for help'
                                  : 'nothing here yet — share what you’re building!',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      children: [
                        if (showStrip) _AsksForYouStrip(asks: forMe),
                        for (final p in shown) _PostCard(post: p),
                      ],
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
          child: FloatingActionButton.extended(
            onPressed: () => showComposePostSheet(
              context,
              ref,
              initialKind: filter ?? FeedKind.show,
            ),
            backgroundColor: AppColors.ink,
            icon: const Icon(Icons.edit_rounded, color: AppColors.onInk),
            label: Text(
              filter == FeedKind.ask ? 'Ask' : 'Post',
              style: const TextStyle(
                  color: AppColors.onInk, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _KindFilterBar extends ConsumerWidget {
  const _KindFilterBar({required this.selected});

  final FeedKind? selected;

  static const _items = <({String label, FeedKind? kind})>[
    (label: 'All', kind: null),
    (label: 'Asks', kind: FeedKind.ask),
    (label: 'Shows', kind: FeedKind.show),
    (label: 'Offers', kind: FeedKind.offer),
    (label: 'Logs', kind: FeedKind.buildlog),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const Gap(8),
        itemBuilder: (context, i) {
          final it = _items[i];
          final isSel = it.kind == selected;
          return GestureDetector(
            onTap: () => ref.read(feedFilterProvider.notifier).select(it.kind),
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
                it.label,
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

/// Horizontal strip of open asks routed to the viewer by their proven skills —
/// the "you can help here" surface that turns lurkers into helpers.
class _AsksForYouStrip extends StatelessWidget {
  const _AsksForYouStrip({required this.asks});
  final List<FeedPost> asks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, size: 16, color: AppColors.ink),
            const Gap(6),
            Text('ASKS THAT MATCH YOUR SKILLS',
                style: AppTypography.mono(
                    fontSize: 9.5, letterSpacing: 1.2, color: AppColors.textMuted)),
          ],
        ),
        const Gap(10),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: asks.length,
            separatorBuilder: (_, _) => const Gap(10),
            itemBuilder: (context, i) {
              final a = asks[i];
              return GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      PostDetailScreen(post: a, autofocus: true),
                )),
                child: Container(
                  width: 230,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('@${a.username}',
                          style: AppTypography.mono(
                              fontSize: 10, color: AppColors.onInkFaint)),
                      const Gap(6),
                      Expanded(
                        child: Text(
                          a.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.onInk, height: 1.3),
                        ),
                      ),
                      const Gap(8),
                      Row(
                        children: [
                          if (a.skillTags.isNotEmpty)
                            Expanded(
                              child: Text(
                                a.skillTags.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.mono(
                                    fontSize: 9.5, color: AppColors.onInkFaint),
                              ),
                            ),
                          const Gap(6),
                          const Text('help →',
                              style: TextStyle(
                                  color: AppColors.onInk,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Gap(18),
      ],
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
    setState(() {
      _upvoted = !_upvoted;
      _count += _upvoted ? 1 : -1;
    });
    try {
      final newState =
          await ref.read(feedRepositoryProvider).toggleUpvote(widget.post.id);
      if (mounted && newState != _upvoted) {
        setState(() => _upvoted = newState);
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

  void _openAuthor() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PublicProfileScreen(userId: widget.post.authorId),
    ));
  }

  void _openPost({bool focus = false}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PostDetailScreen(post: widget.post, autofocus: focus),
    ));
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _onMenu(String v) async {
    final post = widget.post;
    final repo = ref.read(feedRepositoryProvider);
    try {
      if (v == 'report') {
        await repo.report(type: 'post', id: post.id);
        if (mounted) _snack('Reported — thanks, we’ll take a look.');
      } else if (v == 'block') {
        await ref.read(profileRepositoryProvider).blockUser(post.authorId);
        ref.invalidate(feedProvider);
        ref.invalidate(asksForMeProvider);
        if (mounted) {
          _snack('Blocked @${post.username} — you won’t see their posts.');
        }
      } else if (v == 'delete') {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Delete this post?'),
            content: const Text('This can’t be undone.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete')),
            ],
          ),
        );
        if (ok != true) return;
        await repo.deletePost(post.id);
        ref.invalidate(feedProvider);
        if (mounted) _snack('Post deleted.');
      }
    } catch (e) {
      if (mounted) _snack('Something went wrong: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final textTheme = Theme.of(context).textTheme;
    final isAsk = post.isAsk;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        // Open asks get a stronger edge — they're a call for help.
        border: Border.all(
          color: isAsk && post.status == 'open'
              ? AppColors.ink
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _openAuthor,
                child: MeshAvatar(config: post.avatar, size: 40),
              ),
              const Gap(12),
              Expanded(
                child: GestureDetector(
                  onTap: _openAuthor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.authorName, style: textTheme.titleSmall),
                      Text(_ago(post.createdAt),
                          style: AppTypography.mono(fontSize: 10.5)),
                    ],
                  ),
                ),
              ),
              _KindBadge(kind: post.kind, status: post.status),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded,
                    size: 18, color: AppColors.textMuted),
                padding: EdgeInsets.zero,
                onSelected: _onMenu,
                itemBuilder: (_) => post.authorId == SupabaseService.currentUser?.id
                    ? const [
                        PopupMenuItem(value: 'delete', child: Text('Delete post')),
                      ]
                    : [
                        const PopupMenuItem(
                            value: 'report', child: Text('Report post')),
                        PopupMenuItem(
                            value: 'block',
                            child: Text('Block @${post.username}')),
                      ],
              ),
            ],
          ),
          if (isAsk && post.matchScore > 0) ...[
            const Gap(8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, size: 13, color: AppColors.ink),
                const Gap(4),
                Text(
                  'matches ${post.matchScore} of your skills',
                  style: AppTypography.mono(
                      fontSize: 9.5, color: AppColors.ink, letterSpacing: 0.2),
                ),
              ],
            ),
          ],
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openPost(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.body.isNotEmpty) ...[
                  const Gap(12),
                  Text(post.body,
                      style: textTheme.bodyLarge?.copyWith(height: 1.35)),
                ],
                if (post.imageUrl != null) ...[
                  const Gap(12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      post.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (c, child, p) => p == null
                          ? child
                          : const SizedBox(
                              height: 180,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                      errorBuilder: (c, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                if (post.skillTags.isNotEmpty) ...[
                  const Gap(12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in post.skillTags) _Tag(label: t),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Gap(12),
          Row(
            children: [
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
                    Text('$_count',
                        style: TextStyle(
                          color: _upvoted ? AppColors.ink : AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
              const Gap(16),
              GestureDetector(
                onTap: () => _openPost(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mode_comment_outlined,
                        size: 16, color: AppColors.textMuted),
                    const Gap(6),
                    Text('${post.commentCount}',
                        style: const TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Spacer(),
              // Asks invite an answer; offers invite a reply — both open the
              // thread with the composer focused.
              if (isAsk && post.status != 'solved')
                _CardAction(label: 'I can help', onTap: () => _openPost(focus: true))
              else if (post.kind == FeedKind.offer)
                _CardAction(
                    label: 'Reach out', onTap: () => _openPost(focus: true)),
            ],
          ),
        ],
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind, this.status});
  final FeedKind kind;
  final String? status;

  @override
  Widget build(BuildContext context) {
    // Solved asks read as resolved; open asks + offers get an inked badge.
    final solved = kind == FeedKind.ask && status == 'solved';
    final emphasize = (kind == FeedKind.ask && status == 'open') ||
        kind == FeedKind.offer;
    final label = solved ? 'solved' : kind.label.toLowerCase();
    final bg = solved
        ? AppColors.success
        : (emphasize ? AppColors.ink : AppColors.surfaceHigh);
    final fg = (solved || emphasize) ? AppColors.onInk : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTypography.mono(fontSize: 9, letterSpacing: 0.8, color: fg),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label,
            style: AppTypography.mono(
                fontSize: 10, color: AppColors.ink, letterSpacing: 0.2)),
      );
}

class _CardAction extends StatelessWidget {
  const _CardAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 34,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: Text(label),
        ),
      );
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  return '${d.inDays}d';
}
