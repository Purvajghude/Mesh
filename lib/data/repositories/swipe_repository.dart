import '../models/deck_profile.dart';
import '../services/supabase_service.dart';

/// Fetches the swipe deck and records swipe decisions (which also resolve
/// matches) via server-side RPCs.
class SwipeRepository {
  const SwipeRepository();

  Future<List<DeckProfile>> getDeck({int limit = 20}) async {
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
