import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/avatar_config.dart';
import '../../../shared/widgets/mesh_avatar.dart';
import '../application/profile_providers.dart';
import 'avatar_picker_screen.dart';

/// The user's own profile: avatar, identity, vibe, stats, and skills.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);
    final skillsAsync = ref.watch(mySkillsProvider);
    final textTheme = Theme.of(context).textTheme;

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load profile: $e')),
      data: (profile) {
        if (profile == null) {
          return const Center(child: Text('No profile yet.'));
        }
        final avatar = AvatarConfig.fromJson(
          profile['avatar_config'] as Map<String, dynamic>?,
        );
        final username = profile['username'] as String? ?? '';
        final displayName = profile['display_name'] as String?;
        final vibe = profile['vibe_statement'] as String?;
        final reputation = (profile['reputation'] as num?)?.toDouble() ?? 5.0;
        final collabs = (profile['collab_count'] as num?)?.toInt() ?? 0;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myProfileProvider);
            ref.invalidate(mySkillsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _editAvatar(context, ref, avatar),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          MeshAvatar(config: avatar, size: 128),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.ink,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 16,
                              color: AppColors.onInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(16),
                    Text(
                      displayName?.isNotEmpty == true ? displayName! : '@$username',
                      style: textTheme.headlineMedium,
                    ),
                    if (displayName?.isNotEmpty == true)
                      Text('@$username', style: textTheme.bodyMedium),
                  ],
                ),
              ),
              const Gap(20),
              _VibeCard(
                vibe: vibe,
                onEdit: () => _editVibe(context, ref, vibe),
              ),
              const Gap(16),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.star_rounded,
                      iconColor: AppColors.ink,
                      label: 'reputation',
                      value: reputation.toStringAsFixed(1),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.handshake_rounded,
                      iconColor: AppColors.ink,
                      label: 'collabs',
                      value: '$collabs',
                    ),
                  ),
                ],
              ),
              const Gap(24),
              Text('skills', style: textTheme.titleMedium),
              const Gap(12),
              skillsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Could not load skills: $e'),
                data: (skills) {
                  if (skills.isEmpty) {
                    return Text(
                      'No skills yet — import from GitHub or add some.',
                      style: textTheme.bodyMedium,
                    );
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final row in skills)
                        _SkillChip(
                          name: (row['skills']
                                  as Map<String, dynamic>?)?['name']
                              as String? ??
                              '?',
                          verified: row['verified'] == true,
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editAvatar(
    BuildContext context,
    WidgetRef ref,
    AvatarConfig current,
  ) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AvatarPickerScreen(initial: current),
      ),
    );
    if (changed == true) ref.invalidate(myProfileProvider);
  }

  Future<void> _editVibe(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final controller = TextEditingController(text: current ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('what do you love building?',
                style: Theme.of(ctx).textTheme.titleMedium),
            const Gap(16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 120,
              maxLines: 3,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                hintText: 'e.g. weekend game jams + lo-fi beats',
              ),
            ),
            const Gap(8),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await ref.read(profileRepositoryProvider).updateVibe(controller.text);
      ref.invalidate(myProfileProvider);
    }
  }
}

class _VibeCard extends StatelessWidget {
  const _VibeCard({required this.vibe, required this.onEdit});

  final String? vibe;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasVibe = vibe?.isNotEmpty == true;
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasVibe ? vibe! : 'add a vibe — what do you love building?',
                style: TextStyle(
                  color: hasVibe ? AppColors.text : AppColors.textFaint,
                  fontStyle: hasVibe ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
            const Icon(Icons.edit_outlined,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor),
          const Gap(6),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.name, required this.verified});

  final String name;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: AppTypography.mono(
              fontSize: 12.5,
              color: AppColors.ink,
              letterSpacing: 0.2,
            ),
          ),
          if (verified) ...[
            const Gap(6),
            const Icon(Icons.verified, size: 14, color: AppColors.ink),
          ],
        ],
      ),
    );
  }
}
