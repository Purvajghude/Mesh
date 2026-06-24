/// A skill on the signed-in user's own profile, with its earned mastery level.
class MySkill {
  const MySkill({
    required this.id,
    required this.name,
    required this.level,
    required this.xp,
    this.isCompound = false,
    this.blurb,
    this.verified = false,
  });

  final String id;
  final String name;
  final int level; // 1–5
  final double xp;
  final bool isCompound; // crafted from two other skills
  final String? blurb;
  final bool verified;

  static int _levelFromWeight(double w) => (w * 5).round().clamp(1, 5);

  /// From a `profile_skills` row joined with `skills(...)`.
  factory MySkill.fromRow(Map<String, dynamic> row) {
    final s = row['skills'] as Map<String, dynamic>?;
    final weight = (row['weight'] as num?)?.toDouble() ?? 0;
    return MySkill(
      id: row['skill_id'] as String,
      name: s?['name'] as String? ?? '?',
      level: _levelFromWeight(weight),
      xp: (row['xp'] as num?)?.toDouble() ?? 0,
      isCompound: s?['is_compound'] == true,
      blurb: s?['blurb'] as String?,
      verified: row['verified'] == true,
    );
  }

  /// From the backend add/craft endpoint response.
  factory MySkill.fromApi(Map<String, dynamic> json) => MySkill(
        id: json['id'] as String,
        name: json['name'] as String,
        level: (json['level'] as num?)?.toInt() ?? 1,
        xp: (json['xp'] as num?)?.toDouble() ?? 0,
        isCompound: json['crafted_now'] != null || json['blurb'] != null,
        blurb: json['blurb'] as String?,
      );
}
