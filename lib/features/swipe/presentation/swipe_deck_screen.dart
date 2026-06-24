import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/avatar_config.dart';
import '../../../data/services/pitch_service.dart';
import '../../../data/models/chat.dart';
import '../../../data/models/deck_profile.dart';
import '../../chat/application/chat_providers.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../profile/application/profile_providers.dart';
import '../../../shared/widgets/mesh_lattice.dart';
import '../application/swipe_providers.dart';
import 'swipe_card.dart';
import 'match_overlay.dart';

class SwipeDeckScreen extends ConsumerStatefulWidget {
  const SwipeDeckScreen({super.key});

  @override
  ConsumerState<SwipeDeckScreen> createState() => _SwipeDeckScreenState();
}

class _SwipeDeckScreenState extends ConsumerState<SwipeDeckScreen> {
  final _controller = CardSwiperController();
  DateTime _shownAt = DateTime.now();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _dirToString(CardSwiperDirection d) => switch (d) {
        CardSwiperDirection.right => 'right',
        CardSwiperDirection.top => 'up',
        _ => 'left',
      };

  Future<void> _sendIcebreaker(String matchId) async {
    try {
      final pitchSet = await PitchService().fetchPitches(matchId);
      if (pitchSet.pitches.isEmpty) return;
      final pitch = pitchSet.pitches.first;
      await ref.read(chatRepositoryProvider).sendMessage(
            matchId: matchId,
            body: 'hey — mesh thinks we should build this 👀\n\n'
                '${pitch.name}: ${pitch.tagline}\n\n'
                'first step: ${pitch.firstStep}',
          );
    } catch (_) {
      // best-effort — don't block navigation if pitch fetch or send fails
    }
  }

  bool _onSwipe(
    List<DeckProfile> deck,
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) {
    final profile = deck[previousIndex];
    final elapsed = DateTime.now().difference(_shownAt).inMilliseconds;
    _shownAt = DateTime.now();
    _handleSwipe(profile, _dirToString(direction), elapsed);
    return true;
  }

  Future<void> _handleSwipe(
    DeckProfile profile,
    String direction,
    int timeMs,
  ) async {
    final result = await ref.read(swipeRepositoryProvider).recordSwipe(
          targetId: profile.id,
          direction: direction,
          timeSpentMs: timeMs,
        );
    if (!result.matched || !mounted) return;

    final myProfile = ref.read(myProfileProvider).asData?.value;
    final myAvatar = AvatarConfig.fromJson(
      myProfile?['avatar_config'] as Map<String, dynamic>?,
    );
    final sayHi = await showMatchOverlay(
      context,
      myAvatar: myAvatar,
      other: profile,
      matchId: result.matchId,
    );

    if (sayHi == true && result.matchId != null && mounted) {
      ref.invalidate(matchesProvider);
      unawaited(_sendIcebreaker(result.matchId!));
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            match: ChatMatch(
              matchId: result.matchId!,
              otherId: profile.id,
              username: profile.username,
              displayName: profile.displayName,
              avatar: profile.avatar,
              matchedAt: DateTime.now(),
              lastMessage: null,
              lastMessageAt: null,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deckAsync = ref.watch(deckProvider);

    return deckAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
        message: '$e',
        onRetry: () => ref.invalidate(deckProvider),
      ),
      data: (deck) {
        if (deck.isEmpty) {
          return _EmptyState(onRefresh: () => ref.invalidate(deckProvider));
        }
        return Stack(
          children: [
            const Positioned.fill(child: MeshLattice()),
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: CardSwiper(
                  controller: _controller,
                  cardsCount: deck.length,
                  numberOfCardsDisplayed: deck.length >= 3 ? 3 : deck.length,
                  backCardOffset: const Offset(0, 44),
                  padding: EdgeInsets.zero,
                  allowedSwipeDirection: const AllowedSwipeDirection.only(
                    left: true,
                    right: true,
                    up: true,
                  ),
                  onSwipe: (prev, curr, dir) => _onSwipe(deck, prev, curr, dir),
                  onEnd: () => ref.invalidate(deckProvider),
                  cardBuilder: (context, index, _, _) =>
                      SwipeCard(profile: deck[index]),
                ),
              ),
            ),
                _ActionBar(
                  onNope: () => _controller.swipe(CardSwiperDirection.left),
                  onSuper: () => _controller.swipe(CardSwiperDirection.top),
                  onLike: () => _controller.swipe(CardSwiperDirection.right),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.onNope,
    required this.onSuper,
    required this.onLike,
  });

  final VoidCallback onNope;
  final VoidCallback onSuper;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActionButton(
            icon: Icons.close_rounded,
            label: 'NOPE',
            size: 60,
            onTap: onNope,
          ),
          _ActionButton(
            icon: Icons.bolt_rounded,
            label: 'BOOST',
            size: 48,
            tone: AppColors.textMuted,
            onTap: onSuper,
          ),
          _ActionButton(
            icon: Icons.north_east_rounded,
            label: 'MESH',
            size: 60,
            filled: true,
            onTap: onLike,
          ),
        ],
      ),
    );
  }
}

/// Affordance comes from fill, not hue: nope is an outline, boost is a subdued
/// outline, mesh (the like) is the one solid ink fill.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.size,
    required this.onTap,
    this.filled = false,
    this.tone = AppColors.ink,
  });

  final IconData icon;
  final String label;
  final double size;
  final VoidCallback onTap;
  final bool filled;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? AppColors.ink : AppColors.surface,
              border: Border.all(
                color: filled ? AppColors.ink : tone,
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: filled ? AppColors.onInk : tone,
              size: size * 0.4,
            ),
          ),
          const Gap(8),
          Text(
            label,
            style: AppTypography.mono(
              fontSize: 9,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.done_all_rounded,
              size: 56, color: AppColors.textFaint),
          const Gap(16),
          Text('you’re all caught up',
              style: Theme.of(context).textTheme.titleMedium),
          const Gap(4),
          Text('check back for new builders',
              style: Theme.of(context).textTheme.bodyMedium),
          const Gap(20),
          OutlinedButton(onPressed: onRefresh, child: const Text('Refresh')),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('couldn’t load the deck',
              style: Theme.of(context).textTheme.titleMedium),
          const Gap(8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          const Gap(16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
