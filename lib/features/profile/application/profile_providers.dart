import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/models/my_skill.dart';
import '../../../data/services/portfolio_service.dart';
import '../../../data/services/supabase_service.dart';

/// The signed-in user's profile row. Invalidate to refresh after edits.
final myProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) {
  return ref.watch(profileRepositoryProvider).myProfile();
});

/// The signed-in user's skills, strongest first.
final mySkillsProvider = FutureProvider<List<MySkill>>((ref) {
  return ref.watch(profileRepositoryProvider).mySkills();
});

/// External accounts the user has connected (provider -> handle), for showing
/// connected state on the "proof of skill" section.
final connectedAccountsProvider =
    FutureProvider<Map<String, String>>((ref) async {
  if (!SupabaseService.isSignedIn) return {};
  final accounts = await ref.watch(integrationServiceProvider).list();
  return {for (final a in accounts) a.provider: a.handle};
});

/// The signed-in user's AI-judged portfolio evidence entries.
final myPortfolioProvider = FutureProvider<List<PortfolioEntry>>((ref) async {
  if (!SupabaseService.isSignedIn) return const [];
  return ref.watch(portfolioServiceProvider).list();
});
