import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/services/supabase_service.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/auth/presentation/email_auth_screen.dart';
import '../features/auth/presentation/landing_screen.dart';
import '../features/auth/presentation/password_auth_screen.dart';
import '../features/home/presentation/home_shell.dart';
import '../features/onboarding/application/onboarding_providers.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';

/// App router, integrated with Riverpod so it redirects on both auth changes
/// and onboarding completion.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref
    ..listen(authStateProvider, (_, _) => refresh.value++)
    ..listen(onboardingStatusProvider, (_, _) => refresh.value++);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = SupabaseService.isSignedIn;
      final onboarded =
          ref.read(onboardingStatusProvider).asData?.value ?? false;

      final loc = state.matchedLocation;
      final inAuth = loc == '/' || loc.startsWith('/auth');
      final inOnboarding = loc.startsWith('/onboarding');

      if (!signedIn) return inAuth ? null : '/';
      if (!onboarded) return inOnboarding ? null : '/onboarding';
      if (inAuth || inOnboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/auth/email',
        builder: (context, state) => const PasswordAuthScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) => const EmailAuthScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeShell(),
      ),
    ],
  );
});
