import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/models/help_stat.dart';
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

/// Any builder's public profile row, by user id.
final profileByIdProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, id) {
  return ref.watch(profileRepositoryProvider).profileById(id);
});

/// Any builder's skills, by user id.
final skillsByIdProvider =
    FutureProvider.family<List<MySkill>, String>((ref, id) {
  return ref.watch(profileRepositoryProvider).skillsById(id);
});

/// Any builder's per-skill helping reputation (expert badges), by user id.
final helpProfileProvider =
    FutureProvider.family<List<HelpStat>, String>((ref, id) {
  return ref.watch(profileRepositoryProvider).helpProfile(id);
});

/// Top helpers overall — the leaderboard.
final topHelpersProvider = FutureProvider<List<TopHelper>>((ref) {
  return ref.watch(profileRepositoryProvider).topHelpers();
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
