import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/data_providers.dart';
import '../../../data/services/github_service.dart';
import '../../auth/application/auth_providers.dart';
import '../application/onboarding_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _usernameController = TextEditingController();

  bool _busy = false;
  String? _error;
  GithubImport? _result;
  // True only when the import came from a GitHub account the user proved they
  // own (GitHub OAuth). Drives whether the skills are saved as verified.
  bool _ownershipVerified = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    // Prefer the OAuth-verified GitHub identity; a typed username can't be
    // trusted, so anything imported from it is saved unverified.
    final verified = ref.read(authRepositoryProvider).verifiedGithubUsername;
    final username = (verified ?? _usernameController.text).trim();
    if (username.isEmpty) {
      setState(() => _error = 'Enter your GitHub username.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _ownershipVerified = verified != null;
    });
    try {
      final data = await ref.read(githubServiceProvider).importProfile(username);
      setState(() => _result = data);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final data = _result;
    if (data == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .saveGithubImport(data, verified: _ownershipVerified);
      if (_ownershipVerified) {
        final verifiedUser =
            ref.read(authRepositoryProvider).verifiedGithubUsername;
        if (verifiedUser != null) {
          // Fire-and-forget: award XP based on actual GitHub repos. Never
          // blocks onboarding — the backend is best-effort during onboarding.
          unawaited(ref
              .read(integrationServiceProvider)
              .connectGithubOAuth(verifiedUser));
        }
      }
      ref.read(onboardingStatusProvider.notifier).markOnboarded();
      // Router redirects to /home once onboarded flips.
    } catch (e) {
      setState(() {
        _error = '$e';
        _busy = false;
      });
    }
  }

  Future<void> _skip() async {
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).completeOnboarding();
      ref.read(onboardingStatusProvider.notifier).markOnboarded();
    } catch (e) {
      setState(() {
        _error = '$e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
          child: _result == null ? _buildConnect(context) : _buildPreview(context),
        ),
      ),
    );
  }

  Widget _buildConnect(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // If they signed in with GitHub we already KNOW (and trust) their username
    // — import from it, no typing, skills come out verified.
    final verifiedUser = ref.read(authRepositoryProvider).verifiedGithubUsername;
    final hasVerified = verifiedUser != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(12),
        Text('build your', style: textTheme.headlineMedium),
        Text('skill profile', style: textTheme.displaySmall),
        const Gap(12),
        Text(
          hasVerified
              ? 'You signed in with GitHub — we’ll read your public repos and '
                  'turn them into verified, earned skills.'
              : 'We’ll read public GitHub repos to auto-detect languages and '
                  'tools.',
          style: textTheme.bodyMedium,
        ),
        const Gap(32),
        if (hasVerified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, size: 18, color: AppColors.onInk),
                const Gap(10),
                Expanded(
                  child: Text('@$verifiedUser',
                      style: AppTypography.mono(
                          fontSize: 14, color: AppColors.onInk)),
                ),
                Text('verified',
                    style: AppTypography.mono(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        color: AppColors.onInkFaint)),
              ],
            ),
          )
        else ...[
          TextField(
            controller: _usernameController,
            autofocus: true,
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.code_rounded, color: AppColors.textMuted),
              hintText: 'your github username',
            ),
            onSubmitted: (_) => _busy ? null : _import(),
          ),
          const Gap(10),
          Text(
            'Skills imported from a typed username stay unverified. To earn a '
            'verified badge, sign in with GitHub or connect it from your profile.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textFaint),
          ),
        ],
        if (_error != null) ...[
          const Gap(12),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
        const Gap(24),
        ElevatedButton(
          onPressed: _busy ? null : _import,
          child: _busy
              ? const _Spinner()
              : Text(hasVerified ? 'Import my skills' : 'Import (unverified)'),
        ),
        const Spacer(),
        Center(
          child: TextButton(
            onPressed: _busy ? null : _skip,
            child: Text(
              "I'll do it later",
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final data = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(12),
        Row(
          children: [
            Expanded(
              child: Text(
                data.displayName?.isNotEmpty == true
                    ? data.displayName!
                    : '@${data.username}',
                style: textTheme.headlineMedium,
              ),
            ),
            Text('${data.publicRepos} repos', style: textTheme.bodySmall),
          ],
        ),
        const Gap(4),
        Text('found ${data.skills.length} skills', style: textTheme.titleLarge),
        if (data.bio?.isNotEmpty == true) ...[
          const Gap(8),
          Text(data.bio!, style: textTheme.bodyMedium),
        ],
        const Gap(24),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < data.skills.length; i++)
                  _SkillChip(skill: data.skills[i])
                      .animate(delay: (i * 30).ms)
                      .fadeIn(duration: 250.ms)
                      .scale(begin: const Offset(0.8, 0.8)),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const Gap(8),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
        const Gap(12),
        // The culture moment — set the norm right as they feel "it knows me".
        Row(
          children: [
            const Icon(Icons.volunteer_activism_rounded,
                size: 16, color: AppColors.textMuted),
            const Gap(8),
            Expanded(
              child: Text(
                'Mesh runs on builders helping builders — the more you help, '
                'the more you’re seen.',
                style: textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const Gap(12),
        ElevatedButton(
          onPressed: _busy ? null : _confirm,
          child: _busy ? const _Spinner() : const Text("Looks right — let's go"),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _result = null;
                    _error = null;
                  }),
          child: const Text('Try a different username'),
        ),
      ],
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.skill});

  final ImportedSkill skill;

  @override
  Widget build(BuildContext context) {
    // Stronger skills get more presence: the strongest are filled ink, the rest
    // sit as outlined chips. Weight, not colour, carries the emphasis.
    final strong = skill.weight > 0.6;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: strong ? AppColors.ink : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: strong ? AppColors.ink : AppColors.border),
      ),
      child: Text(
        skill.name,
        style: AppTypography.mono(
          fontSize: 12.5,
          color: strong ? AppColors.onInk : AppColors.ink,
          fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 22,
      width: 22,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}
