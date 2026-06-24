import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';

/// Thin wrapper around the Supabase client.
///
/// [init] must be awaited once during bootstrap. Everywhere else, read
/// [client] / [auth] for a guaranteed-initialised instance.
class SupabaseService {
  const SupabaseService._();

  static Future<void> init() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // Using the legacy anon key (JWT). Still fully supported; migrate to
      // `publishableKey` if/when we rotate to the new Supabase key system.
      // ignore: deprecated_member_use
      anonKey: Env.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => client.auth;

  /// The currently signed-in user, or null when signed out.
  static User? get currentUser => auth.currentUser;

  /// The current access token (JWT), sent to the AI backend so it can verify
  /// who the caller is. Null when signed out.
  static String? get accessToken => auth.currentSession?.accessToken;

  static bool get isSignedIn => currentUser != null;
}
