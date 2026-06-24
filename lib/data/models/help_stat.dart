import 'avatar_config.dart';

/// A user's helping reputation in one skill (powers "Expert in X" badges).
class HelpStat {
  const HelpStat({
    required this.skillName,
    required this.karma,
    required this.helps,
    required this.expert,
  });

  final String skillName;
  final int karma;
  final int helps;
  final bool expert;

  factory HelpStat.fromJson(Map<String, dynamic> json) => HelpStat(
        skillName: json['skill_name'] as String? ?? '?',
        karma: (json['karma'] as num?)?.toInt() ?? 0,
        helps: (json['helps'] as num?)?.toInt() ?? 0,
        expert: json['expert'] == true,
      );
}

/// A row on the top-helpers leaderboard.
class TopHelper {
  const TopHelper({
    required this.profileId,
    required this.username,
    required this.displayName,
    required this.avatar,
    required this.karma,
    required this.helps,
  });

  final String profileId;
  final String username;
  final String? displayName;
  final AvatarConfig avatar;
  final int karma;
  final int helps;

  String get name =>
      (displayName?.isNotEmpty == true) ? displayName! : '@$username';

  factory TopHelper.fromJson(Map<String, dynamic> json) => TopHelper(
        profileId: json['profile_id'] as String,
        username: json['username'] as String? ?? '',
        displayName: json['display_name'] as String?,
        avatar: AvatarConfig.fromJson(
          json['avatar_config'] as Map<String, dynamic>?,
        ),
        karma: (json['karma'] as num?)?.toInt() ?? 0,
        helps: (json['helps'] as num?)?.toInt() ?? 0,
      );
}
