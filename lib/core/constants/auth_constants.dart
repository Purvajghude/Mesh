import 'package:flutter/foundation.dart';

/// Auth-related constants shared across the auth feature.
abstract final class AuthConstants {
  /// Deep-link the OAuth provider redirects back to after sign-in.
  ///
  /// On web, Supabase redirects to the page origin automatically, so we pass
  /// null and let the SDK handle it. On native platforms we use a custom URL
  /// scheme that must be registered in each platform's native config.
  static String? get oauthRedirect =>
      kIsWeb ? null : 'com.mesh.app://login-callback';
}
