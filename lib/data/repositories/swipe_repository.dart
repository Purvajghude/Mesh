import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/deck_profile.dart';
import '../services/api_config.dart';
import '../services/supabase_service.dart';

/// Fetches the swipe deck and records swipe decisions (which also resolve
/// matches) via server-side RPCs.
class SwipeRepository {
  const SwipeRepository();

  /// The complementarity-ranked deck from the AI backend, falling back to the
  /// plain Supabase RPC if the backend is unreachable — so the app always shows
  /// a deck even if the ranking service is down.
  Future<List<DeckProfile>> getDeck({int limit = 20}) async {
    if (SupabaseService.accessToken != null) {
      try {
        final res = await http
            .get(
              Uri.parse('${ApiConfig.baseUrl}/deck?limit=$limit'),
              headers: ApiConfig.headers(),
            )
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final rows = (body['deck'] as List<dynamic>?) ?? const [];
          if (rows.isNotEmpty) {
            return [
              for (final r in rows)
                DeckProfile.fromJson(r as Map<String, dynamic>),
            ];
          }
        }
      } catch (_) {
        // fall through to the RPC below
      }
    }
    return _getDeckRpc(limit: limit);
  }

  Future<List<DeckProfile>> _getDeckRpc({int limit = 20}) async {
    final rows = await SupabaseService.client
        .rpc('get_deck', params: {'p_limit': limit}) as List<dynamic>;
    return [
      for (final r in rows) DeckProfile.fromJson(r as Map<String, dynamic>),
    ];
  }

  /// Records a swipe. Returns whether it matched and the match id if so.
  Future<SwipeResult> recordSwipe({
    required String targetId,
    required String direction, // 'left' | 'right' | 'up'
    int? timeSpentMs,
  }) async {
    final res = await SupabaseService.client.rpc('record_swipe', params: {
      'p_target': targetId,
      'p_direction': direction,
      'p_time_ms': timeSpentMs,
    }) as Map<String, dynamic>;
    return SwipeResult(
      matched: res['matched'] == true,
      matchId: res['match_id'] as String?,
    );
  }
}

class SwipeResult {
  const SwipeResult({required this.matched, this.matchId});
  final bool matched;
  final String? matchId;
}
