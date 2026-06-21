import '../models/feed_post.dart';
import '../services/supabase_service.dart';

class FeedRepository {
  const FeedRepository();

  /// Posts for a channel, or all channels when [channel] is null.
  Future<List<FeedPost>> getFeed({String? channel}) async {
    final rows = await SupabaseService.client.rpc(
      'get_feed',
      params: {'p_channel': channel},
    ) as List<dynamic>;
    return [
      for (final r in rows) FeedPost.fromJson(r as Map<String, dynamic>),
    ];
  }

  /// Toggles the current user's upvote. Returns the new upvoted state.
  Future<bool> toggleUpvote(String postId) async {
    final res = await SupabaseService.client.rpc(
      'toggle_upvote',
      params: {'p_post': postId},
    ) as Map<String, dynamic>;
    return res['upvoted'] == true;
  }

  Future<void> createPost({
    required String channel,
    required String body,
  }) async {
    final me = SupabaseService.currentUser!.id;
    await SupabaseService.client.from('feed_posts').insert({
      'author_id': me,
      'channel': channel,
      'body': body.trim(),
    });
  }
}
