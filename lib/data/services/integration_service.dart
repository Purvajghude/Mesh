import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'skill_service.dart' show SkillException;

/// One skill's XP grant from connecting an account.
class AwardedXp {
  const AwardedXp({required this.skill, required this.xp, required this.why});
  final String skill;
  final double xp;
  final String why;

  factory AwardedXp.fromJson(Map<String, dynamic> j) => AwardedXp(
        skill: j['skill'] as String,
        xp: (j['xp'] as num?)?.toDouble() ?? 0,
        why: j['why'] as String? ?? '',
      );
}

class ConnectResult {
  const ConnectResult({
    required this.provider,
    required this.label,
    required this.handle,
    required this.awarded,
  });
  final String provider;
  final String label;
  final String handle;
  final List<AwardedXp> awarded;

  factory ConnectResult.fromJson(Map<String, dynamic> j) => ConnectResult(
        provider: j['provider'] as String,
        label: j['label'] as String? ?? j['provider'] as String,
        handle: j['handle'] as String? ?? '',
        awarded: [
          for (final a in (j['awarded'] as List<dynamic>? ?? const []))
            AwardedXp.fromJson(a as Map<String, dynamic>),
        ],
      );
}

class ConnectedAccount {
  const ConnectedAccount({required this.provider, required this.handle});
  final String provider;
  final String handle;
}

/// Connect external accounts (GitHub now; more via the same backend framework)
/// to earn proof-of-skill XP.
class IntegrationService {
  /// Request a one-time ownership code to place in your platform profile.
  /// Returns {nonce, field, label}.
  Future<Map<String, String>> challenge(String provider) async {
    final res = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/integrations/challenge'),
          headers: ApiConfig.headers(),
          body: jsonEncode({'provider': provider}),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw SkillException(body['detail']?.toString() ?? 'Challenge failed');
    }
    return {
      'nonce': body['nonce'] as String? ?? '',
      'field': body['field'] as String? ?? 'your profile',
      'label': body['label'] as String? ?? provider,
    };
  }

  Future<ConnectResult> connect(String provider, String handle) async {
    final res = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/integrations/connect'),
          headers: ApiConfig.headers(),
          body: jsonEncode({'provider': provider, 'handle': handle}),
        )
        .timeout(const Duration(seconds: 40));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw SkillException(body['detail']?.toString() ?? 'Connect failed');
    }
    return ConnectResult.fromJson(body);
  }

  /// Award GitHub XP for a handle already proven via GitHub OAuth (no nonce needed).
  /// Fire-and-forget safe — catches all errors so onboarding never blocks.
  Future<ConnectResult?> connectGithubOAuth(String handle) async {
    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/integrations/github/oauth-connect'),
            headers: ApiConfig.headers(),
            body: jsonEncode({'handle': handle}),
          )
          .timeout(const Duration(seconds: 40));
      if (res.statusCode != 200) return null;
      return ConnectResult.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<ConnectedAccount>> list() async {
    final res = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/integrations'),
          headers: ApiConfig.headers(),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return const [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return [
      for (final a in (body['accounts'] as List<dynamic>? ?? const []))
        ConnectedAccount(
          provider: (a as Map<String, dynamic>)['provider'] as String,
          handle: a['handle'] as String? ?? '',
        ),
    ];
  }
}
