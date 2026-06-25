import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/avatar_config.dart';
import '../models/help_stat.dart';
import '../models/my_skill.dart';
import '../models/search_result.dart';
import '../services/api_config.dart';
import '../services/github_service.dart';
import '../services/supabase_service.dart';

/// Reads and writes the signed-in user's profile + skills.
class ProfileRepository {
  const ProfileRepository();

  String get _userId {
    final id = SupabaseService.currentUser?.id;
    if (id == null) throw StateError('No signed-in user.');
    return id;
  }

  Future<Map<String, dynamic>?> myProfile() => profileById(_userId);

  /// Any user's public profile row (profiles are readable by authenticated).
  Future<Map<String, dynamic>?> profileById(String id) async {
    final rows = await SupabaseService.client
        .from('profiles')
        .select()
        .eq('id', id)
        .limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  /// The user's skills, strongest first, with earned level + compound metadata.
  Future<List<MySkill>> mySkills() => skillsById(_userId);

  /// A user's per-skill helping reputation (for expert badges on profiles).
  Future<List<HelpStat>> helpProfile(String id) async {
    final rows = await SupabaseService.client
        .rpc('get_help_profile', params: {'p_user': id}) as List<dynamic>;
    return [
      for (final r in rows) HelpStat.fromJson(r as Map<String, dynamic>),
    ];
  }

  /// Search builders by username, display name, or a skill they have.
  Future<List<SearchResult>> searchProfiles(String query, {int limit = 30}) async {
    final rows = await SupabaseService.client.rpc('search_profiles',
        params: {'p_query': query.trim(), 'p_limit': limit}) as List<dynamic>;
    return [
      for (final r in rows) SearchResult.fromJson(r as Map<String, dynamic>),
    ];
  }

  /// Semantic NL search using backend embeddings — falls back gracefully if backend is down.
  Future<List<SearchResult>?> searchProfilesSemantic(String query) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/search')
          .replace(queryParameters: {'q': query.trim()});
      final res = await http
          .get(uri, headers: ApiConfig.headers())
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['results'] as List<dynamic>? ?? const [];
      return [
        for (final r in list) SearchResult.fromJson(r as Map<String, dynamic>),
      ];
    } catch (_) {
      return null; // backend down → caller falls back to text search
    }
  }

  /// Top helpers overall ([skill] null) or within one skill — the leaderboard.
  Future<List<TopHelper>> topHelpers({String? skill, int limit = 20}) async {
    final rows = await SupabaseService.client.rpc('get_top_helpers',
        params: {'p_skill': skill, 'p_limit': limit}) as List<dynamic>;
    return [
      for (final r in rows) TopHelper.fromJson(r as Map<String, dynamic>),
    ];
  }

  /// Any user's skills, strongest first (for viewing another builder's profile).
  Future<List<MySkill>> skillsById(String id) async {
    final rows = await SupabaseService.client
        .from('profile_skills')
        .select(
          'skill_id, weight, xp, source, verified, '
          'skills(name, category, is_compound, blurb)',
        )
        .eq('profile_id', id)
        .order('weight', ascending: false);
    return [
      for (final r in rows) MySkill.fromRow(r),
    ];
  }

  Future<void> updateAvatar(AvatarConfig config) async {
    await SupabaseService.client
        .from('profiles')
        .update({'avatar_config': config.toJson()}).eq('id', _userId);
  }

  Future<void> updateVibe(String vibe) async {
    await SupabaseService.client
        .from('profiles')
        .update({'vibe_statement': vibe.trim()}).eq('id', _userId);
  }

  Future<void> updateDisplayName(String name) async {
    await SupabaseService.client
        .from('profiles')
        .update({'display_name': name.trim()}).eq('id', _userId);
  }

  /// Block a user — hides their posts, comments, and search presence both ways.
  Future<void> blockUser(String id) =>
      SupabaseService.client.rpc('block_user', params: {'p_target': id});

  Future<void> unblockUser(String id) =>
      SupabaseService.client.rpc('unblock_user', params: {'p_target': id});

  /// Report a user for review.
  Future<void> reportUser(String id, {String? reason}) =>
      SupabaseService.client.rpc('report_content',
          params: {'p_type': 'user', 'p_id': id, 'p_reason': reason});

  Future<void> updateChatBg(String key) async {
    await SupabaseService.client
        .from('profiles')
        .update({'chat_bg': key}).eq('id', _userId);
  }

  /// Uploads a custom chat background image to the public 'chat-media' bucket
  /// and points the profile at it (chat_bg = 'custom').
  Future<void> uploadCustomChatBg({
    required Uint8List bytes,
    required String filename,
    String? mime,
  }) async {
    final userId = _userId;
    final safe = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    // uid-first path so the own-folder storage policy passes.
    final path = '$userId/bg/${DateTime.now().millisecondsSinceEpoch}_$safe';
    await SupabaseService.client.storage.from('chat-media').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime ?? 'image/jpeg', upsert: true),
        );
    final url =
        SupabaseService.client.storage.from('chat-media').getPublicUrl(path);
    await SupabaseService.client
        .from('profiles')
        .update({'chat_bg': 'custom', 'chat_bg_url': url}).eq('id', userId);
  }

  /// Persists a GitHub import: upserts the skill catalog, links the skills to
  /// the user, and stamps the profile as onboarded. [verified] is true ONLY
  /// when ownership was proven (GitHub OAuth) — a typed username imports skills
  /// but leaves them unverified.
  Future<void> saveGithubImport(GithubImport data,
      {required bool verified}) async {
    final client = SupabaseService.client;
    final userId = _userId;

    if (data.skills.isNotEmpty) {
      // 1. Ensure each skill exists in the shared catalog.
      await client.from('skills').upsert(
        [
          for (final s in data.skills) {'name': s.name, 'category': s.category},
        ],
        onConflict: 'name',
        ignoreDuplicates: true,
      );

      // 2. Resolve their ids.
      final names = data.skills.map((s) => s.name).toList();
      final rows =
          await client.from('skills').select('id, name').inFilter('name', names);
      final idByName = {
        for (final r in rows) r['name'] as String: r['id'] as String,
      };

      // 3. Link them to this user (idempotent).
      await client.from('profile_skills').upsert(
        [
          for (final s in data.skills)
            if (idByName[s.name] != null)
              {
                'profile_id': userId,
                'skill_id': idByName[s.name],
                'source': 'github',
                'verified': verified,
                'weight': s.weight,
              },
        ],
        onConflict: 'profile_id,skill_id',
        ignoreDuplicates: true,
      );
    }

    // 4. Stamp the profile.
    await client.from('profiles').update({
      'github_username': data.username,
      'onboarded': true,
      if (data.displayName != null && data.displayName!.isNotEmpty)
        'display_name': data.displayName,
    }).eq('id', userId);
  }

  /// Marks onboarding complete without a GitHub import (e.g. resume/manual path).
  Future<void> completeOnboarding() async {
    await SupabaseService.client
        .from('profiles')
        .update({'onboarded': true}).eq('id', _userId);
  }
}
