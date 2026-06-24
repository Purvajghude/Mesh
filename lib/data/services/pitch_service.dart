import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/pitch.dart';
import 'api_config.dart';

class PitchService {
  Future<PitchSet> fetchPitches(
    String matchId, {
    bool forceRefresh = false,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/pitches'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'match_id': matchId,
            'force_refresh': forceRefresh,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Pitch API ${response.statusCode}: ${response.body}');
    }

    return PitchSet.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
