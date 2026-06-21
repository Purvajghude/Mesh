import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/services/github_service.dart';
import '../../../shared/widgets/gradient_text.dart';
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

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(githubServiceProvider)
          .importProfile(_usernameController.text);
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
      await ref.read(profileRepositoryProvider).saveGithubImport(data);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(12),
        Text('build your', style: textTheme.headlineMedium),
        GradientText(
          'skill profile',
          gradient: AppColors.brandGradient,
          style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Gap(12),
        Text(
          'Connect GitHub and we’ll read your public repos to auto-detect your '
          'languages and tools. No manual typing.',
          style: textTheme.bodyMedium,
        ),
        const Gap(32),
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
        if (_error != null) ...[
          const Gap(12),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
        const Gap(24),
        ElevatedButton(
          onPressed: _busy ? null : _import,
          child: _busy
              ? const _Spinner()
              : const Text('Import my skills'),
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
        GradientText(
          'found ${data.skills.length} skills',
          gradient: AppColors.brandGradient,
          style: textTheme.titleLarge,
        ),
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
    final isLanguage = skill.category == 'language';
    // Stronger skills get more presence.
    final accent = isLanguage ? AppColors.primary : AppColors.cyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10 + 0.12 * skill.weight),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Text(
        skill.name,
        style: TextStyle(
          color: AppColors.text,
          fontWeight: skill.weight > 0.75 ? FontWeight.w700 : FontWeight.w500,
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
