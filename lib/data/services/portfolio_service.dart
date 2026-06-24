import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'skill_service.dart' show SkillException;

class PortfolioAward {
  const PortfolioAward({required this.skill, required this.xp, required this.reasoning});
  final String skill;
  final double xp;
  final String reasoning;

  factory PortfolioAward.fromJson(Map<String, dynamic> j) => PortfolioAward(
        skill: j['skill'] as String,
        xp: (j['xp'] as num?)?.toDouble() ?? 0,
        reasoning: j['reasoning'] as String? ?? '',
      );
}

class PortfolioVerdict {
  const PortfolioVerdict({
    required this.title,
    required this.summary,
    required this.credible,
    required this.captureMode,
    required this.awarded,
  });
  final String title;
  final String summary;
  final bool credible;
  final String captureMode; // 'camera' | 'upload'
  final List<PortfolioAward> awarded;

  bool get live => captureMode == 'camera';

  factory PortfolioVerdict.fromJson(Map<String, dynamic> j) => PortfolioVerdict(
        title: j['title'] as String? ?? '',
        summary: j['summary'] as String? ?? '',
        credible: j['credible'] as bool? ?? false,
        captureMode: j['capture_mode'] as String? ?? 'upload',
        awarded: [
          for (final a in (j['awarded'] as List<dynamic>? ?? const []))
            PortfolioAward.fromJson(a as Map<String, dynamic>),
        ],
      );
}

class PortfolioEntry {
  const PortfolioEntry({
    required this.id,
    required this.title,
    required this.live,
    required this.skills,
  });
  final String id;
  final String title;
  final bool live;
  final List<String> skills;

  factory PortfolioEntry.fromJson(Map<String, dynamic> j) => PortfolioEntry(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        live: (j['capture_mode'] as String?) == 'camera',
        skills: [
          for (final s in (j['skills'] as List<dynamic>? ?? const []))
            if (s != null) s as String,
        ],
      );
}

/// Submits portfolio evidence (base64, ephemeral — never stored) for AI-judged
/// skill XP. Live camera capture earns full XP; uploads earn a reduced share.
class PortfolioService {
  Future<PortfolioVerdict> submit({
    required String title,
    required String description,
    required List<String> imagesB64,
    required List<String> links,
    required String captureMode, // 'camera' | 'upload'
  }) async {
    final res = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/portfolio/submit'),
          headers: ApiConfig.headers(),
          body: jsonEncode({
            'title': title,
            'description': description,
            'images_b64': imagesB64,
            'links': links,
            'capture_mode': captureMode,
          }),
        )
        .timeout(const Duration(seconds: 60));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw SkillException(body['detail']?.toString() ?? 'Submit failed');
    }
    return PortfolioVerdict.fromJson(body);
  }

  Future<List<PortfolioEntry>> list() async {
    final res = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/portfolio'),
          headers: ApiConfig.headers(),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return const [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return [
      for (final e in (body['evidence'] as List<dynamic>? ?? const []))
        PortfolioEntry.fromJson(e as Map<String, dynamic>),
    ];
  }
}
