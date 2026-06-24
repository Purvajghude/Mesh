import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/feed_comment.dart';
import '../models/feed_post.dart';
import '../services/feed_ai_service.dart';
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

  /// Open asks routed to you — those needing a skill you've proven, best first.
  Future<List<FeedPost>> asksForMe({int limit = 20}) async {
    final rows = await SupabaseService.client
        .rpc('get_asks_for_me', params: {'p_limit': limit}) as List<dynamic>;
    return [
      for (final r in rows) FeedPost.fromJson(r as Map<String, dynamic>),
    ];
  }

  /// Comments (answers) on a post, oldest first.
  Future<List<FeedComment>> comments(String postId) async {
    final rows = await SupabaseService.client
        .rpc('get_post_comments', params: {'p_post': postId}) as List<dynamic>;
    return [
      for (final r in rows) FeedComment.fromJson(r as Map<String, dynamic>),
    ];
  }

  /// Post a comment/answer. Bumps the count and moves an open ask → answered.
  Future<void> addComment(String postId, String body) async {
    await SupabaseService.client
        .rpc('add_comment', params: {'p_post': postId, 'p_body': body});
  }

  /// Asker marks the comment that solved their ask → status 'solved'.
  Future<void> markSolved(String postId, String commentId) async {
    await SupabaseService.client.rpc('mark_ask_solved',
        params: {'p_post': postId, 'p_comment': commentId});
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
    required FeedKind kind,
    required String body,
    List<String> skillTags = const [],
    Uint8List? imageBytes,
    String? imageName,
    String? imageMime,
  }) async {
    final me = SupabaseService.currentUser!.id;
    String? imageUrl;
    if (imageBytes != null) {
      imageUrl = await _uploadImage(me, imageBytes, imageName, imageMime);
    }
    final row = await SupabaseService.client.from('feed_posts').insert({
      'author_id': me,
      'channel': 'general',
      'kind': kind.name,
      'body': body.trim(),
      'skill_tags': skillTags,
      // Asks track resolution; other kinds have no status.
      'status': kind == FeedKind.ask ? 'open' : null,
      'image_url': ?imageUrl,
    }).select('id').single();

    // Best-effort AI passes (don't block the UI; fine if the backend is down):
    // moderate every post; give asks an instant first-pass answer.
    final id = row['id'] as String;
    final ai = FeedAiService();
    unawaited(ai.moderate(id));
    if (kind == FeedKind.ask) unawaited(ai.answerAsk(id));
  }

  /// Uploads a feed image to the public 'portfolio' bucket and returns its URL.
  Future<String> _uploadImage(
    String userId,
    Uint8List bytes,
    String? name,
    String? mime,
  ) async {
    final safe = (name ?? 'image.jpg').replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = 'feed/$userId/${DateTime.now().millisecondsSinceEpoch}_$safe';
    await SupabaseService.client.storage.from('portfolio').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime ?? 'image/jpeg'),
        );
    return SupabaseService.client.storage.from('portfolio').getPublicUrl(path);
  }
}
