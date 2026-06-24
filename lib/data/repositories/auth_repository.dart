import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/auth_constants.dart';
import '../services/supabase_service.dart';

/// All authentication flows funnel through here so the rest of the app never
/// touches the Supabase auth client directly.
class AuthRepository {
  const AuthRepository();

  GoTrueClient get _auth => SupabaseService.auth;

  /// Emits on every sign-in / sign-out / token refresh.
  Stream<AuthState> authStateChanges() => _auth.onAuthStateChange;

  User? get currentUser => _auth.currentUser;

  bool get isSignedIn => currentUser != null;

  /// GitHub OAuth — the hero flow. The `read:user` scope lets us later pull
  /// repos/languages to auto-build the user's skill profile.
  Future<void> signInWithGitHub() {
    return _auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: AuthConstants.oauthRedirect,
      scopes: 'read:user user:email',
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  /// Google OAuth — universal sign-in.
  Future<void> signInWithGoogle() {
    return _auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AuthConstants.oauthRedirect,
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  /// Create a new account with email + password. When Supabase email
  /// confirmation is OFF, this returns a live session immediately. When it's ON,
  /// [AuthResponse.session] is null and the user must confirm via email first.
  Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
  }) {
    return _auth.signUp(email: email.trim(), password: password);
  }

  /// Sign in to an existing account with email + password.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// Sends a one-time code to [email]. No redirect/deep-link needed, which
  /// makes it the reliable path for desktop dev testing.
  Future<void> sendEmailOtp(String email) {
    return _auth.signInWithOtp(email: email.trim());
  }

  /// Completes the email OTP flow with the 6-digit [token].
  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) {
    return _auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
  }

  Future<void> signOut() => _auth.signOut();
}
