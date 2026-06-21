import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/services/supabase_service.dart';
import '../../auth/application/auth_providers.dart';

export '../../../data/data_providers.dart' show githubServiceProvider, profileRepositoryProvider;

/// Tracks whether the signed-in user has finished onboarding. Drives routing:
/// signed-in-but-not-onboarded users are sent to the onboarding flow.
class OnboardingStatusNotifier extends Notifier<AsyncValue<bool>> {
  @override
  AsyncValue<bool> build() {
    // Re-evaluate whenever auth changes (sign-in / sign-out).
    ref.watch(authStateProvider);
    _load();
    return const AsyncValue.loading();
  }

  Future<void> _load() async {
    if (!SupabaseService.isSignedIn) {
      state = const AsyncValue.data(false);
      return;
    }
    try {
      final profile = await ref.read(profileRepositoryProvider).myProfile();
      state = AsyncValue.data((profile?['onboarded'] as bool?) ?? false);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Called when the user finishes onboarding so routing updates immediately.
  void markOnboarded() => state = const AsyncValue.data(true);
}

final onboardingStatusProvider =
    NotifierProvider<OnboardingStatusNotifier, AsyncValue<bool>>(
  OnboardingStatusNotifier.new,
);
