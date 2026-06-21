import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Type-safe access to environment variables loaded from `.env`.
///
/// Call [Env.load] once during app bootstrap before reading any value.
class Env {
  const Env._();

  static Future<void> load() => dotenv.load();

  static String get supabaseUrl => _require('SUPABASE_URL');
  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');

  /// Reads a required key, throwing a clear error if it is missing so we fail
  /// fast at startup instead of hitting a cryptic null later.
  static String _require(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) {
      throw StateError(
        'Missing required env var "$key". '
        'Copy .env.example to .env and fill it in.',
      );
    }
    return value;
  }
}
