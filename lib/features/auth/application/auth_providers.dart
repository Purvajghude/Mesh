import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/auth_repository.dart';

/// Single shared [AuthRepository] instance.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const AuthRepository(),
);

/// Streams Supabase auth changes so the UI reacts to sign-in / sign-out.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// The current signed-in user (or null), derived from [authStateProvider] but
/// falling back to the synchronous current value for first build.
final currentUserProvider = Provider<User?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  // Re-read whenever auth state emits.
  ref.watch(authStateProvider);
  return repo.currentUser;
});
