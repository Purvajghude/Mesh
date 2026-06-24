import 'avatar_config.dart';

/// A skill on a profile, with its earned mastery level (1–5) from the EXP
/// system. Level is derived from proficiency weight when the backend doesn't
/// send one (e.g. the RPC fallback deck).
class DeckSkill {
  const DeckSkill({required this.name, required this.level, this.xp = 0});

  final String name;
  final int level; // 1–5
  final double xp;

  factory DeckSkill.fromJson(Map<String, dynamic> json) {
    final weight = (json['weight'] as num?)?.toDouble() ?? 0.6;
    final level = (json['level'] as num?)?.toInt() ??
        (weight * 5).round().clamp(1, 5);
    return DeckSkill(
      name: json['name'] as String,
      level: level < 1 ? 1 : level,
      xp: (json['xp'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// A candidate shown in the swipe deck.
class DeckProfile {
  const DeckProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.vibe,
    required this.avatar,
    required this.reputation,
    required this.skills,
    this.explanation,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? vibe;
  final AvatarConfig avatar;
  final double reputation;
  final List<DeckSkill> skills;

  /// Why the engine surfaced this builder ("fills your gap in X · you both
  /// touch Y"). Present when the deck comes from the ranking endpoint.
  final String? explanation;

  String get name =>
      (displayName?.isNotEmpty == true) ? displayName! : '@$username';

  factory DeckProfile.fromJson(Map<String, dynamic> json) {
    final rawSkills = (json['skills'] as List<dynamic>?) ?? const [];
    return DeckProfile(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String?,
      vibe: json['vibe_statement'] as String?,
      avatar: AvatarConfig.fromJson(
        json['avatar_config'] as Map<String, dynamic>?,
      ),
      reputation: (json['reputation'] as num?)?.toDouble() ?? 5.0,
      skills: [
        for (final s in rawSkills)
          DeckSkill.fromJson(s as Map<String, dynamic>),
      ],
      explanation: json['explanation'] as String?,
    );
  }
}
