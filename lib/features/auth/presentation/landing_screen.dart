import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../shared/widgets/mesh_lattice.dart';
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
          SnackBar(content: Text("Couldn't sign in: $e")),
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
          const Positioned.fill(child: MeshLattice()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Text(
                    'MESH — FOR BUILDERS',
                    style: AppTypography.mono(letterSpacing: 2),
                  ).animate().fadeIn(duration: 500.ms),
                  const Gap(14),
                  Text(
                    'mesh',
                    style: AppTypography.display(fontSize: 88),
                  ).animate().fadeIn(duration: 600.ms).slideY(
                        begin: 0.18,
                        curve: Curves.easeOutCubic,
                      ),
                  const Gap(14),
                  Text(
                    'find people whose skills\nfit yours.',
                    style: textTheme.headlineSmall?.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                      height: 1.15,
                    ),
                  ).animate(delay: 200.ms).fadeIn(duration: 600.ms),
                  const Spacer(),
                  _AuthButton(
                    label: 'Continue with GitHub',
                    icon: Icons.code_rounded,
                    filled: true,
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
                        'or use email',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ).animate(delay: 600.ms).fadeIn(),
                  const Gap(10),
                  Center(
                    child: Text(
                      'NO PHOTOS · JUST SKILLS',
                      style: AppTypography.mono(
                        fontSize: 9.5,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ).animate(delay: 700.ms).fadeIn(),
                ],
              ),
            ),
          ),
          if (_busy)
            ColoredBox(
              color: AppColors.ink.withValues(alpha: 0.4),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.onInk),
              ),
            ),
        ],
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
    this.iconSize = 22,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? AppColors.onInk : AppColors.ink;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: fg, size: iconSize),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? AppColors.ink : Colors.transparent,
          foregroundColor: fg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: filled ? AppColors.ink : AppColors.ink,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
