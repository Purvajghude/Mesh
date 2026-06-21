import 'dart:convert';

import 'package:http/http.dart' as http;

/// A skill inferred from a GitHub account.
class ImportedSkill {
  const ImportedSkill({
    required this.name,
    required this.category,
    required this.weight,
  });

  final String name;
  final String category; // 'language' | 'topic'
  final double weight; // 0..1 relative confidence

  ImportedSkill copyWith({double? weight}) => ImportedSkill(
        name: name,
        category: category,
        weight: weight ?? this.weight,
      );
}

/// Result of importing a public GitHub profile.
class GithubImport {
  const GithubImport({
    required this.username,
    required this.displayName,
    required this.bio,
    required this.publicRepos,
    required this.skills,
  });

  final String username;
  final String? displayName;
  final String? bio;
  final int publicRepos;
  final List<ImportedSkill> skills;
}

/// Reads PUBLIC GitHub data (no OAuth needed) and turns a user's repos into a
/// ranked skill list. Unauthenticated GitHub API allows 60 requests/hour,
/// which is plenty — one import is just two requests.
class GithubService {
  GithubService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _base = 'https://api.github.com';

  Future<GithubImport> importProfile(String rawUsername) async {
    final username = rawUsername.trim().replaceAll('@', '');
    if (username.isEmpty) {
      throw const GithubException('Enter a GitHub username.');
    }

    final user = await _getJson('$_base/users/$username');
    if (user == null) {
      throw GithubException('No GitHub user "$username" found.');
    }

    final repos = await _getJsonList(
      '$_base/users/$username/repos?per_page=100&sort=pushed&type=owner',
    );

    final skills = _deriveSkills(repos ?? const []);

    return GithubImport(
      username: username,
      displayName: user['name'] as String?,
      bio: user['bio'] as String?,
      publicRepos: (user['public_repos'] as num?)?.toInt() ?? 0,
      skills: skills,
    );
  }

  /// Aggregates primary languages and repo topics into weighted skills.
  List<ImportedSkill> _deriveSkills(List<dynamic> repos) {
    final langCounts = <String, int>{};
    final topicCounts = <String, int>{};

    for (final raw in repos) {
      final repo = raw as Map<String, dynamic>;
      if (repo['fork'] == true) continue; // skip forks — not their work

      final lang = repo['language'] as String?;
      if (lang != null && lang.isNotEmpty) {
        langCounts[lang] = (langCounts[lang] ?? 0) + 1;
      }
      final topics = (repo['topics'] as List<dynamic>?) ?? const [];
      for (final t in topics) {
        final topic = t as String;
        topicCounts[topic] = (topicCounts[topic] ?? 0) + 1;
      }
    }

    final maxLang =
        langCounts.values.fold<int>(1, (m, v) => v > m ? v : m).toDouble();
    final maxTopic =
        topicCounts.values.fold<int>(1, (m, v) => v > m ? v : m).toDouble();

    final skills = <ImportedSkill>[
      for (final e in langCounts.entries)
        ImportedSkill(
          name: e.key,
          category: 'language',
          weight: 0.5 + 0.5 * (e.value / maxLang),
        ),
      for (final e in topicCounts.entries)
        ImportedSkill(
          name: _prettifyTopic(e.key),
          category: 'topic',
          weight: 0.4 + 0.4 * (e.value / maxTopic),
        ),
    ]..sort((a, b) => b.weight.compareTo(a.weight));

    return skills;
  }

  String _prettifyTopic(String topic) {
    return topic
        .split('-')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Future<Map<String, dynamic>?> _getJson(String url) async {
    final res = await _client.get(Uri.parse(url), headers: _headers);
    if (res.statusCode == 404) return null;
    _checkRate(res);
    if (res.statusCode != 200) {
      throw GithubException('GitHub error ${res.statusCode}.');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>?> _getJsonList(String url) async {
    final res = await _client.get(Uri.parse(url), headers: _headers);
    if (res.statusCode == 404) return null;
    _checkRate(res);
    if (res.statusCode != 200) {
      throw GithubException('GitHub error ${res.statusCode}.');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  void _checkRate(http.Response res) {
    if (res.statusCode == 403 &&
        res.headers['x-ratelimit-remaining'] == '0') {
      throw const GithubException(
        'GitHub rate limit reached. Try again in a bit.',
      );
    }
  }

  static const _headers = {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };
}

class GithubException implements Exception {
  const GithubException(this.message);
  final String message;
  @override
  String toString() => message;
}
