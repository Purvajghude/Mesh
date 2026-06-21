import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';

/// The signed-in user's profile row. Invalidate to refresh after edits.
final myProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) {
  return ref.watch(profileRepositoryProvider).myProfile();
});

/// The signed-in user's skills, strongest first.
final mySkillsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(profileRepositoryProvider).mySkills();
});
