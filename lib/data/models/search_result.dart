import 'avatar_config.dart';

/// A builder returned from search — matched by name or by a skill they have.
class SearchResult {
  const SearchResult({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatar,
    required this.helpKarma,
    required this.helpsCount,
    this.matchedSkill,
  });

  final String id;
  final String username;
  final String? displayName;
  final AvatarConfig avatar;
  final int helpKarma;
  final int helpsCount;
  final String? matchedSkill; // the skill that matched the query, if any

  String get name =>
      (displayName?.isNotEmpty == true) ? displayName! : '@$username';

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        id: json['id'] as String,
        username: json['username'] as String? ?? '',
        displayName: json['display_name'] as String?,
        avatar: AvatarConfig.fromJson(
          json['avatar_config'] as Map<String, dynamic>?,
        ),
        helpKarma: (json['help_karma'] as num?)?.toInt() ?? 0,
        helpsCount: (json['helps_count'] as num?)?.toInt() ?? 0,
        matchedSkill: json['matched_skill'] as String?,
      );
}
