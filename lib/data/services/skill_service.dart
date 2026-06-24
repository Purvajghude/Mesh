import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/my_skill.dart';
import 'api_config.dart';

/// Talks to the open-vocabulary skill + crafting endpoints on the AI backend.
class SkillService {
  /// Add any skill by name. New skills are embedded server-side on the fly.
  /// The acting user is derived from the auth token, not sent in the body.
  Future<MySkill> addSkill(String name) async {
    final res = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/profile/skills'),
          headers: ApiConfig.headers(),
          body: jsonEncode({'name': name}),
        )
        .timeout(const Duration(seconds: 30));
    return MySkill.fromApi(_decode(res));
  }

  /// Combine two or more leveled skills into a higher-order compound skill.
  Future<MySkill> craft(List<String> skillIds) async {
    final res = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/craft'),
          headers: ApiConfig.headers(),
          body: jsonEncode({'skill_ids': skillIds}),
        )
        .timeout(const Duration(seconds: 30));
    return MySkill.fromApi(_decode(res));
  }

  /// The atomic skills a compound skill is crafted from (drill-down view).
  Future<List<SkillComponent>> components(String skillId) async {
    final res = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/skills/$skillId/components'),
          headers: ApiConfig.headers(),
        )
        .timeout(const Duration(seconds: 20));
    final body = _decode(res);
    final list = (body['components'] as List?) ?? const [];
    return [
      for (final c in list) SkillComponent.fromJson(c as Map<String, dynamic>),
    ];
  }

  Map<String, dynamic> _decode(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      // FastAPI puts validation/business errors under "detail".
      throw SkillException(body['detail']?.toString() ?? 'Request failed');
    }
    return body;
  }
}

/// One atomic skill a compound is made of, with the user's own level in it
/// (null if they don't currently have that component on their profile).
class SkillComponent {
  const SkillComponent({
    required this.id,
    required this.name,
    required this.isCompound,
    this.level,
  });

  final String id;
  final String name;
  final bool isCompound;
  final int? level;

  factory SkillComponent.fromJson(Map<String, dynamic> json) => SkillComponent(
        id: json['id'] as String,
        name: json['name'] as String? ?? '?',
        isCompound: json['is_compound'] == true,
        level: (json['level'] as num?)?.toInt(),
      );
}

/// A human-readable error from the skill API (e.g. "both skills must be L3+").
class SkillException implements Exception {
  const SkillException(this.message);
  final String message;
  @override
  String toString() => message;
}
