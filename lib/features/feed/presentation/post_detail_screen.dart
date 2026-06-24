import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/feed_comment.dart';
import '../../../data/models/feed_post.dart';
import '../../../data/services/supabase_service.dart';
import '../../../shared/widgets/mesh_avatar.dart';
import '../../profile/presentation/public_profile_screen.dart';
import '../application/feed_providers.dart';

/// A single feed post with its threaded answers. For asks, the asker can mark
/// the comment that solved it; anyone can add an answer.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({required this.post, this.autofocus = false, super.key});

  final FeedPost post;
  final bool autofocus;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _controller = TextEditingController();
  bool _sending = false;
  late String? _status = widget.post.status;
  String? _solvedCommentId; // highlighted when solved in this session

  String? get _me => SupabaseService.currentUser?.id;
  bool get _isAsker => widget.post.authorId == _me;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await ref.read(feedRepositoryProvider).addComment(widget.post.id, body);
      ref.invalidate(postCommentsProvider(widget.post.id));
      ref.invalidate(feedProvider);
      if (mounted && _status == 'open' && !_isAsker) {
        setState(() => _status = 'answered');
      }
    } catch (e) {
      if (mounted) {
        _controller.text = body;
        _snack("Couldn't post: $e");
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _markSolved(FeedComment c) async {
    try {
      await ref.read(feedRepositoryProvider).markSolved(widget.post.id, c.id);
      ref.invalidate(feedProvider);
      if (mounted) {
        setState(() {
          _status = 'solved';
          _solvedCommentId = c.id;
        });
        _snack('Marked solved — thanks to ${c.authorName} 🙌');
      }
    } catch (e) {
      if (mounted) _snack(_clean(e));
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _clean(Object e) =>
      e.toString().split(':').last.trim();

  void _openProfile(String userId) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PublicProfileScreen(userId: userId),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final commentsAsync = ref.watch(postCommentsProvider(post.id));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(post.kind.label)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                _PostHeader(post: post, status: _status, onAuthor: _openProfile),
                if (post.isAsk && (post.aiAnswer?.isNotEmpty ?? false)) ...[
                  const Gap(12),
                  _AiAnswerCard(answer: post.aiAnswer!),
                ],
                const Gap(20),
                Row(
                  children: [
                    Text('ANSWERS',
                        style: AppTypography.mono(
                            fontSize: 9.5,
                            letterSpacing: 1.5,
                            color: AppColors.textMuted)),
                    const Gap(8),
                    Expanded(child: Container(height: 1, color: AppColors.border)),
                  ],
                ),
                const Gap(12),
                commentsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Could not load answers: $e'),
                  data: (comments) {
                    if (comments.isEmpty) {
                      return Text(
                        post.isAsk
                            ? 'no answers yet — be the one who helps.'
                            : 'no comments yet.',
                        style: textTheme.bodyMedium,
                      );
                    }
                    return Column(
                      children: [
                        for (final c in comments)
                          _CommentTile(
                            comment: c,
                            isSolution: c.id == _solvedCommentId,
                            // Asker can mark a peer's answer as the solution.
                            canMarkSolved: post.isAsk &&
                                _isAsker &&
                                _status != 'solved' &&
                                c.authorId != _me,
                            onMarkSolved: () => _markSolved(c),
                            onAuthor: () => _openProfile(c.authorId),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          _Composer(
            controller: _controller,
            sending: _sending,
            autofocus: widget.autofocus,
            hint: post.isAsk ? 'write an answer…' : 'add a comment…',
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.post, required this.status, required this.onAuthor});
  final FeedPost post;
  final String? status;
  final void Function(String userId) onAuthor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final solved = post.isAsk && status == 'solved';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: post.isAsk && status == 'open'
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
                onTap: () => onAuthor(post.authorId),
                child: MeshAvatar(config: post.avatar, size: 40),
              ),
              const Gap(12),
              Expanded(
                child: GestureDetector(
                  onTap: () => onAuthor(post.authorId),
                  child: Text(post.authorName, style: textTheme.titleSmall),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: solved ? AppColors.success : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  solved ? 'solved' : post.kind.label.toLowerCase(),
                  style: AppTypography.mono(
                    fontSize: 9,
                    letterSpacing: 0.8,
                    color: solved ? AppColors.onInk : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          if (post.body.isNotEmpty) ...[
            const Gap(12),
            Text(post.body,
                style: textTheme.bodyLarge?.copyWith(height: 1.35)),
          ],
          if (post.imageUrl != null) ...[
            const Gap(12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(post.imageUrl!,
                  width: double.infinity, fit: BoxFit.cover),
            ),
          ],
          if (post.skillTags.isNotEmpty) ...[
            const Gap(12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in post.skillTags)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(t,
                        style: AppTypography.mono(
                            fontSize: 10, color: AppColors.ink)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The AI's instant first-pass on an ask — a head start; humans confirm/improve.
class _AiAnswerCard extends StatelessWidget {
  const _AiAnswerCard({required this.answer});
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 16, color: AppColors.ink),
              const Gap(6),
              Text('MESH AI · FIRST PASS',
                  style: AppTypography.mono(
                      fontSize: 9, color: AppColors.textMuted)),
            ],
          ),
          const Gap(8),
          Text(answer,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4)),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.isSolution,
    required this.canMarkSolved,
    required this.onMarkSolved,
    required this.onAuthor,
  });

  final FeedComment comment;
  final bool isSolution;
  final bool canMarkSolved;
  final VoidCallback onMarkSolved;
  final VoidCallback onAuthor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSolution ? AppColors.success : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onAuthor,
                child: MeshAvatar(config: comment.avatar, size: 26),
              ),
              const Gap(8),
              Expanded(
                child: GestureDetector(
                  onTap: onAuthor,
                  child: Text(comment.authorName,
                      style: textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ),
              if (isSolution)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 14, color: AppColors.success),
                    const Gap(4),
                    Text('solution',
                        style: AppTypography.mono(
                            fontSize: 8.5,
                            letterSpacing: 1,
                            color: AppColors.success)),
                  ],
                ),
            ],
          ),
          const Gap(8),
          Text(comment.body, style: textTheme.bodyMedium),
          if (canMarkSolved) ...[
            const Gap(8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onMarkSolved,
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('this solved it'),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.autofocus,
    required this.hint,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final bool autofocus;
  final String hint;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: autofocus,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(color: AppColors.text),
                decoration: InputDecoration(
                  hintText: hint,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const Gap(8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                ),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.onInk),
                      )
                    : const Icon(Icons.arrow_upward_rounded,
                        color: AppColors.onInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
