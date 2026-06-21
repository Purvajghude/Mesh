import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/models/chat.dart';

/// The current user's matches (Crew list). Invalidate to refresh.
final matchesProvider = FutureProvider<List<ChatMatch>>((ref) {
  return ref.watch(chatRepositoryProvider).getMatches();
});

/// Live messages for a given match.
final messagesProvider =
    StreamProvider.family<List<Message>, String>((ref, matchId) {
  return ref.watch(chatRepositoryProvider).messagesStream(matchId);
});

/// Live reactions for a match, grouped by message id.
final reactionsProvider =
    StreamProvider.family<Map<String, List<Reaction>>, String>((ref, matchId) {
  return ref.watch(chatRepositoryProvider).reactionsStream(matchId).map((list) {
    final byMessage = <String, List<Reaction>>{};
    for (final r in list) {
      byMessage.putIfAbsent(r.messageId, () => []).add(r);
    }
    return byMessage;
  });
});

