import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

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
    Uint8List? imageBytes,
    String? imageName,
    String? imageMime,
  }) async {
    final me = SupabaseService.currentUser!.id;
    String? imageUrl;
    if (imageBytes != null) {
      imageUrl = await _uploadImage(me, imageBytes, imageName, imageMime);
    }
    await SupabaseService.client.from('feed_posts').insert({
      'author_id': me,
      'channel': channel,
      'body': body.trim(),
      'image_url': ?imageUrl,
    });
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
