import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../application/auth_providers.dart';

/// Email + password auth with an explicit Create-account / Sign-in toggle.
/// Reliable on every platform — no deep links, no one-time codes.
class PasswordAuthScreen extends ConsumerStatefulWidget {
  const PasswordAuthScreen({super.key});

  @override
  ConsumerState<PasswordAuthScreen> createState() => _PasswordAuthScreenState();
}

class _PasswordAuthScreenState extends ConsumerState<PasswordAuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _register = true; // start on "create account"
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final repo = ref.read(authRepositoryProvider);
    try {
      if (_register) {
        final res = await repo.signUpWithPassword(
          email: email,
          password: password,
        );
        // With email confirmation OFF, a session comes back and the router
        // redirects to onboarding. With it ON, no session → ask them to confirm.
        if (res.session == null && mounted) {
          setState(() => _notice =
              'Account created. Check your email to confirm, then sign in.');
          setState(() => _register = false);
        }
      } else {
        await repo.signInWithPassword(email: email, password: password);
        // On success the auth stream fires and the router redirects home.
      }
    } catch (e) {
      if (mounted) setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Supabase auth errors arrive as AuthException; surface just the message.
  String _humanize(Object e) {
    final s = e.toString().replaceFirst('AuthException', '').trim();
    final msg = s.replaceAll(RegExp(r'^[:(]\s*|\)$'), '').trim();
    if (msg.toLowerCase().contains('already registered')) {
      return 'That email already has an account — try signing in.';
    }
    if (msg.toLowerCase().contains('invalid login')) {
      return 'Wrong email or password.';
    }
    return msg.isEmpty ? 'Something went wrong.' : msg;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _register ? 'create your account' : 'welcome back',
              style: textTheme.headlineMedium,
            ),
            const Gap(8),
            Text(
              _register
                  ? 'join Mesh and start matching with builders who complete '
                      'your stack.'
                  : 'sign in to pick up where you left off.',
              style: textTheme.bodyMedium,
            ),
            const Gap(28),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              autofillHints: const [AutofillHints.email],
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(hintText: 'you@example.com'),
            ),
            const Gap(12),
            TextField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: _register
                  ? const [AutofillHints.newPassword]
                  : const [AutofillHints.password],
              style: const TextStyle(color: AppColors.text),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: _register ? 'choose a password' : 'your password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (_notice != null) ...[
              const Gap(12),
              Text(_notice!,
                  style: const TextStyle(color: AppColors.success)),
            ],
            if (_error != null) ...[
              const Gap(12),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const Gap(24),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_register ? 'Create account' : 'Sign in'),
            ),
            if (_register) ...[
              const Gap(10),
              Text(
                'By creating an account you agree to Mesh’s Terms, and that we '
                'process your skills and activity to match and rank builders.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: AppColors.textFaint),
              ),
            ],
            const Gap(12),
            Center(
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _register = !_register;
                          _error = null;
                          _notice = null;
                        }),
                child: Text(
                  _register
                      ? 'already a member? Sign in'
                      : 'new here? Create an account',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const Spacer(),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => context.push('/auth/otp'),
                child: Text(
                  'email me a one-time code instead',
                  style: AppTypography.mono(
                      fontSize: 10.5,
                      letterSpacing: 0.4,
                      color: AppColors.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
