import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// Calls the AI backend for feed assist: an instant first-pass answer on asks,
/// and a quality/safety moderation pass. Both are best-effort — if the backend
/// is unreachable the post still lives; these just don't run.
class FeedAiService {
  /// Generate + store an AI first-pass answer for an ask. Fire-and-forget safe.
  Future<void> answerAsk(String postId) => _post('/asks/ai-answer', postId);

  /// Run the moderation/quality gate over a post. Fire-and-forget safe.
  Future<void> moderate(String postId) => _post('/feed/moderate', postId);

  Future<void> _post(String path, String postId) async {
    try {
      await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: ApiConfig.headers(),
            body: jsonEncode({'post_id': postId}),
          )
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      // Backend down / slow — non-fatal. The post is already live.
    }
  }
}
