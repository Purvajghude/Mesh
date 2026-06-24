import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/models/feed_comment.dart';
import '../../../data/models/feed_post.dart';

/// Feed kind filter (null = everything). The feed-of-helpers is organized by
/// post kind (asks / shows / offers), not Reddit-style channels.
class FeedFilterNotifier extends Notifier<FeedKind?> {
  @override
  FeedKind? build() => null;

  void select(FeedKind? kind) => state = kind;
}

final feedFilterProvider =
    NotifierProvider<FeedFilterNotifier, FeedKind?>(FeedFilterNotifier.new);

/// All feed posts (newest first). Kind filtering is applied client-side so
/// switching filters is instant and doesn't refetch.
final feedProvider = FutureProvider<List<FeedPost>>((ref) {
  return ref.watch(feedRepositoryProvider).getFeed();
});

/// Comments on a single post (by id).
final postCommentsProvider =
    FutureProvider.family<List<FeedComment>, String>((ref, postId) {
  return ref.watch(feedRepositoryProvider).comments(postId);
});

/// Open asks routed to you by your proven skills (the "asks for you" strip).
final asksForMeProvider = FutureProvider<List<FeedPost>>((ref) {
  return ref.watch(feedRepositoryProvider).asksForMe();
});
