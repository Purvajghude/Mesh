import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/models/deck_profile.dart';

/// Loads the current swipe deck. Invalidate to pull a fresh batch.
final deckProvider = FutureProvider<List<DeckProfile>>((ref) {
  return ref.watch(swipeRepositoryProvider).getDeck();
});
