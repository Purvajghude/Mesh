import 'avatar_config.dart';

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
  });

  final String id;
  final String username;
  final String? displayName;
  final String? vibe;
  final AvatarConfig avatar;
  final double reputation;
  final List<String> skills;

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
          (s as Map<String, dynamic>)['name'] as String,
      ],
    );
  }
}
