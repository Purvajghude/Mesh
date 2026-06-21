import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/gradient_text.dart';
import '../application/auth_providers.dart';

/// First screen an unauthenticated user sees. GitHub is the hero (auto-imports
/// skills later); Google is the universal option; email is the quiet fallback.
class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceHigh,
            content: Text("Couldn't sign in: $e"),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final repo = ref.read(authRepositoryProvider);

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: _Glow(color: AppColors.primary.withValues(alpha: 0.35)),
          ),
          Positioned(
            bottom: -140,
            right: -100,
            child: _Glow(color: AppColors.pink.withValues(alpha: 0.25)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  GradientText(
                    'mesh',
                    gradient: AppColors.brandGradient,
                    style: textTheme.displayLarge?.copyWith(
                      fontSize: 76,
                      fontWeight: FontWeight.w700,
                    ),
                  ).animate().fadeIn(duration: 600.ms).slideY(
                        begin: 0.2,
                        curve: Curves.easeOutCubic,
                      ),
                  const Gap(8),
                  Text(
                    'find people whose skills\nfit yours.',
                    style: textTheme.headlineMedium?.copyWith(
                      color: AppColors.textMuted,
                      height: 1.2,
                    ),
                  ).animate(delay: 200.ms).fadeIn(duration: 600.ms),
                  const Spacer(),
                  _AuthButton(
                    label: 'Continue with GitHub',
                    icon: Icons.code_rounded,
                    onPressed: () => _run(repo.signInWithGitHub),
                  ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.3),
                  const Gap(12),
                  _AuthButton(
                    label: 'Continue with Google',
                    icon: Icons.g_mobiledata_rounded,
                    iconSize: 30,
                    onPressed: () => _run(repo.signInWithGoogle),
                  ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.3),
                  const Gap(16),
                  Center(
                    child: TextButton(
                      onPressed: _busy ? null : () => context.push('/auth/email'),
                      child: Text(
                        'or continue with email',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ).animate(delay: 600.ms).fadeIn(),
                  const Gap(8),
                  Center(
                    child: Text(
                      'no photos. just skills. zero corporate.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textFaint,
                      ),
                    ),
                  ).animate(delay: 700.ms).fadeIn(),
                ],
              ),
            ),
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 160, spreadRadius: 60)],
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.iconSize = 22,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.text, size: iconSize),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surfaceHigh,
          foregroundColor: AppColors.text,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }
}
