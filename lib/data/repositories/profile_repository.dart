import '../models/avatar_config.dart';
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

  Future<Map<String, dynamic>?> myProfile() async {
    final rows = await SupabaseService.client
        .from('profiles')
        .select()
        .eq('id', _userId)
        .limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  /// The user's skills, strongest first, with the skill name/category joined in.
  Future<List<Map<String, dynamic>>> mySkills() async {
    final rows = await SupabaseService.client
        .from('profile_skills')
        .select('weight, source, verified, skills(name, category)')
        .eq('profile_id', _userId)
        .order('weight', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
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

  Future<void> updateChatBg(String key) async {
    await SupabaseService.client
        .from('profiles')
        .update({'chat_bg': key}).eq('id', _userId);
  }

  /// Persists a GitHub import: upserts the skill catalog, links the skills to
  /// the user, and stamps the profile as onboarded.
  Future<void> saveGithubImport(GithubImport data) async {
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
                'verified': true,
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
