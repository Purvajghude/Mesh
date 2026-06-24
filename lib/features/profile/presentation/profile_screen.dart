import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/avatar_config.dart';
import '../../../data/models/my_skill.dart';
import '../../../data/services/api_config.dart';
import '../../../data/services/integration_service.dart';
import '../../../data/services/portfolio_service.dart';
import '../../../data/services/skill_service.dart';
import '../../../shared/widgets/mesh_avatar.dart';
import '../application/profile_providers.dart';
import 'avatar_picker_screen.dart';
import 'helping_section.dart';

/// Connectable proof-of-skill providers. GitHub is live; the rest share the
/// same backend framework and light up as they're wired in.
const _providers = <({String id, String label, bool active})>[
  (id: 'github', label: 'GitHub', active: true),
  (id: 'codeforces', label: 'Codeforces', active: true),
  (id: 'leetcode', label: 'LeetCode', active: true),
  (id: 'chesscom', label: 'Chess.com', active: true),
  (id: 'strava', label: 'Strava', active: false),
];

/// How many atomic skills to show before the "show more" fold.
const _skillFold = 6;

/// The user's own profile: identity, vibe, earned skills, and proof of work.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _showAllSkills = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final skillsAsync = ref.watch(mySkillsProvider);

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
        final helps = (profile['helps_count'] as num?)?.toInt() ?? 0;
        final karma = (profile['help_karma'] as num?)?.toInt() ?? 0;
        final myId = profile['id'] as String;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myProfileProvider);
            ref.invalidate(mySkillsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              _Masthead(
                avatar: avatar,
                displayName: displayName,
                username: username,
                onEditAvatar: () => _editAvatar(context, avatar),
                onEditName: () => _editName(context, displayName),
              ),
              const Gap(20),
              _StatStrip(
                reputation: reputation,
                helps: helps,
                collabs: collabs,
              ),
              const Gap(22),
              _VibePullquote(
                vibe: vibe,
                onEdit: () => _editVibe(context, vibe),
              ),
              const Gap(34),
              HelpingSection(
                userId: myId,
                helpsCount: helps,
                karma: karma,
                isMe: true,
              ),
              const Gap(34),
              _skillsSection(context, skillsAsync),
              const Gap(36),
              _ProofSection(
                profile: profile,
                onConnect: (id, label, prefill) =>
                    _connectProvider(context, id, label, prefill: prefill),
              ),
              const Gap(36),
              _portfolioSection(context),
              const Gap(36),
              const _BackendSetting(),
            ],
          ),
        );
      },
    );
  }

  // ── Skills ─────────────────────────────────────────────────────────────────

  Widget _skillsSection(
    BuildContext context,
    AsyncValue<List<MySkill>> skillsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHead(
          title: 'skills',
          caption: 'level is earned — collabs, repos and projects grow it',
          actions: [
            _MiniAction(
              icon: Icons.add_rounded,
              label: 'add',
              onTap: () => _addSkill(context),
            ),
            _MiniAction(
              icon: Icons.hub_outlined,
              label: 'craft',
              onTap: () => _craftSkill(context),
            ),
          ],
        ),
        const Gap(16),
        skillsAsync.when(
          loading: () =>
              const Padding(padding: EdgeInsets.all(8), child: _Spinner()),
          error: (e, _) => Text('Could not load skills: $e'),
          data: (skills) {
            if (skills.isEmpty) {
              return Text(
                'No skills yet — import from GitHub or tap “add”.',
                style: Theme.of(context).textTheme.bodyMedium,
              );
            }
            // Crafted compounds read as achievements — surface them first and
            // make them tappable to reveal what they're made of.
            final compounds = skills.where((s) => s.isCompound).toList();
            final atomic = [
              for (final s in skills)
                if (!s.isCompound) s,
            ];
            final shown =
                _showAllSkills ? atomic : atomic.take(_skillFold).toList();
            final hidden = atomic.length - shown.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (compounds.isNotEmpty) ...[
                  Text('CRAFTED',
                      style: AppTypography.mono(
                          fontSize: 9, letterSpacing: 1.6)),
                  const Gap(10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in compounds)
                        _SkillChip(
                          skill: s,
                          onTap: () => _showComponents(context, s),
                        ),
                    ],
                  ),
                  const Gap(18),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final s in shown) _SkillChip(skill: s)],
                ),
                if (atomic.length > _skillFold) ...[
                  const Gap(12),
                  _ShowMoreButton(
                    expanded: _showAllSkills,
                    hidden: hidden,
                    onTap: () =>
                        setState(() => _showAllSkills = !_showAllSkills),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  /// Bottom sheet revealing the atomic skills a compound was crafted from.
  Future<void> _showComponents(BuildContext context, MySkill compound) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hub_rounded, size: 20, color: AppColors.ink),
                const Gap(10),
                Expanded(
                  child: Text(compound.name,
                      style: Theme.of(ctx).textTheme.titleLarge),
                ),
                _Pips(level: compound.level),
              ],
            ),
            if (compound.blurb?.isNotEmpty == true) ...[
              const Gap(8),
              Text(compound.blurb!,
                  style: Theme.of(ctx).textTheme.bodyMedium),
            ],
            const Gap(20),
            Text('CRAFTED FROM',
                style: AppTypography.mono(
                    fontSize: 9,
                    letterSpacing: 1.6,
                    color: AppColors.textMuted)),
            const Gap(12),
            FutureBuilder<List<SkillComponent>>(
              future: ref.read(skillServiceProvider).components(compound.id),
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                      padding: EdgeInsets.all(8), child: _Spinner());
                }
                final comps = snap.data ?? const [];
                if (comps.isEmpty) {
                  return Text(
                    "the recipe for this one isn't recorded.",
                    style: Theme.of(ctx).textTheme.bodySmall,
                  );
                }
                return Column(
                  children: [
                    for (final c in comps) _ComponentRow(component: c),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Portfolio ──────────────────────────────────────────────────────────────

  Widget _portfolioSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHead(
          title: 'portfolio',
          caption: 'no platform for it? show your work — AI verifies it into XP',
          actions: [
            _MiniAction(
              icon: Icons.add_photo_alternate_outlined,
              label: 'add evidence',
              onTap: () => _addEvidence(context),
            ),
          ],
        ),
        const Gap(16),
        Builder(
          builder: (context) {
            final entries = ref.watch(myPortfolioProvider).value ?? const [];
            if (entries.isEmpty) {
              return Text(
                'add a project — photos of hardware, design, cooking, a shoot '
                '— and the AI judge turns it into skill XP.',
                style: Theme.of(context).textTheme.bodyMedium,
              );
            }
            return Column(
              children: [
                for (final e in entries) _PortfolioCard(entry: e),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _addEvidence(BuildContext context) async {
    // Live camera = verified, full XP. Upload = can't verify it's yours, less XP.
    final mode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.ink),
              title: const Text('Capture live'),
              subtitle: const Text('verified in real time — full XP'),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.textMuted),
              title: const Text('Upload from gallery'),
              subtitle: const Text("can't verify it's yours — reduced XP"),
              onTap: () => Navigator.of(ctx).pop('upload'),
            ),
            const Gap(8),
          ],
        ),
      ),
    );
    if (mode == null) return;

    final picker = ImagePicker();
    final List<XFile> files;
    if (mode == 'camera') {
      final shot = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        imageQuality: 70,
      );
      files = shot == null ? const [] : [shot];
    } else {
      files = await picker.pickMultiImage(maxWidth: 1280, imageQuality: 70);
    }
    if (files.isEmpty || !context.mounted) return;

    final titleController = TextEditingController();
    final descController = TextEditingController();
    final linksController = TextEditingController();
    final go = await showModalBottomSheet<bool>(
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
            Text(
              mode == 'camera'
                  ? '📸 ${files.length} live photo'
                  : '${files.length} photo(s) selected',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const Gap(6),
            Text(
              'describe what you made — the AI judge reads this + your photos.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const Gap(14),
            TextField(
              controller: titleController,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                hintText: 'title — e.g. Handmade looper pedal',
              ),
            ),
            const Gap(10),
            TextField(
              controller: descController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                hintText: 'what you did, how you built it',
              ),
            ),
            const Gap(10),
            TextField(
              controller: linksController,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                hintText: 'links (optional, comma-separated)',
              ),
            ),
            const Gap(14),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Submit for evaluation'),
            ),
          ],
        ),
      ),
    );
    if (go != true || titleController.text.trim().isEmpty) return;
    if (!context.mounted) return;

    _snack(context, mode == 'camera'
        ? 'verifying live capture with AI…'
        : 'evaluating upload with AI…');
    try {
      final imagesB64 = <String>[
        for (final f in files) base64Encode(await f.readAsBytes()),
      ];
      final links = linksController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final verdict = await ref.read(portfolioServiceProvider).submit(
            title: titleController.text.trim(),
            description: descController.text.trim(),
            imagesB64: imagesB64,
            links: links,
            captureMode: mode,
          );
      ref.invalidate(mySkillsProvider);
      ref.invalidate(myProfileProvider);
      ref.invalidate(myPortfolioProvider);
      if (context.mounted) _showVerdict(context, verdict);
    } on SkillException catch (e) {
      if (context.mounted) _snack(context, e.message);
    } catch (_) {
      if (context.mounted) {
        _snack(context, "couldn't evaluate — is the AI backend running?");
      }
    }
  }

  void _showVerdict(BuildContext context, PortfolioVerdict verdict) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.ink, size: 20),
            Gap(8),
            Expanded(child: Text('AI verdict')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              verdict.live ? '📸 verified live' : 'uploaded · reduced XP',
              style: AppTypography.mono(
                fontSize: 9.5,
                letterSpacing: 1.2,
                color: verdict.live ? AppColors.ink : AppColors.textMuted,
              ),
            ),
            const Gap(8),
            if (verdict.summary.isNotEmpty)
              Text(verdict.summary,
                  style: Theme.of(ctx).textTheme.bodyMedium),
            if (verdict.awarded.isEmpty) ...[
              const Gap(10),
              Text(
                "no XP this time — the evidence didn't clearly demonstrate a skill.",
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ] else ...[
              const Gap(14),
              Text('EARNED XP',
                  style: AppTypography.mono(
                      fontSize: 9.5, letterSpacing: 1.5, color: AppColors.textMuted)),
              const Gap(8),
              for (final a in verdict.awarded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('+${a.xp.toStringAsFixed(0)}  ${a.skill}',
                          style: Theme.of(ctx).textTheme.bodyLarge),
                      Text(a.reasoning,
                          style: Theme.of(ctx).textTheme.bodySmall),
                    ],
                  ),
                ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Nice'),
          ),
        ],
      ),
    );
  }

  // ── Proof-of-skill providers ────────────────────────────────────────────────

  Future<void> _connectProvider(
    BuildContext context,
    String provider,
    String label, {
    String? prefill,
  }) async {
    final controller = TextEditingController(text: prefill ?? '');
    final handle = await showModalBottomSheet<String>(
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
            Text('connect $label', style: Theme.of(ctx).textTheme.titleMedium),
            const Gap(6),
            Text(
              'we read your public $label activity and turn it into earned XP '
              'on the matching skills.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const Gap(16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(hintText: 'your $label username'),
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
            ),
            const Gap(12),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text('Connect $label'),
            ),
          ],
        ),
      ),
    );
    if (handle == null || handle.trim().isEmpty || !context.mounted) return;
    final svc = ref.read(integrationServiceProvider);

    // Step 2 — get a one-time ownership code.
    Map<String, String> ch;
    try {
      ch = await svc.challenge(provider);
    } on SkillException catch (e) {
      if (context.mounted) _snack(context, e.message);
      return;
    } catch (_) {
      if (context.mounted) _snack(context, "couldn't reach the backend");
      return;
    }
    if (!context.mounted) return;

    // Step 3 — user puts the code in their profile, then taps Verify.
    final verify = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('verify your $label'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add this code to ${ch['field']} (you can remove it after):',
                style: Theme.of(ctx).textTheme.bodyMedium),
            const Gap(12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: SelectableText(
                ch['nonce'] ?? '',
                style: AppTypography.mono(
                  fontSize: 15, color: AppColors.ink, letterSpacing: 1),
              ),
            ),
            const Gap(12),
            Text(
              "then tap Verify — we check it's really your account before "
              'awarding any XP.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    if (verify != true || !context.mounted) return;

    // Step 4 — connect: re-reads the profile field, awards XP if the code is there.
    _snack(context, 'verifying $label…');
    try {
      final result = await svc.connect(provider, handle.trim());
      ref.invalidate(mySkillsProvider);
      ref.invalidate(myProfileProvider);
      ref.invalidate(connectedAccountsProvider);
      if (context.mounted) _showConnectResult(context, result);
    } on SkillException catch (e) {
      if (context.mounted) _snack(context, e.message);
    } catch (_) {
      if (context.mounted) {
        _snack(context, "couldn't connect — is the AI backend running?");
      }
    }
  }

  void _showConnectResult(BuildContext context, ConnectResult result) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('${result.label} connected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.awarded.isEmpty)
              Text('already synced — no new XP this time.',
                  style: Theme.of(ctx).textTheme.bodyMedium)
            else ...[
              Text('EARNED XP', style: AppTypography.mono(fontSize: 9.5, letterSpacing: 1.5, color: AppColors.textMuted)),
              const Gap(10),
              for (final a in result.awarded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '+${a.xp.toStringAsFixed(0)}  ${a.skill}  ·  ${a.why}',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Nice'),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _addSkill(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showModalBottomSheet<String>(
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
            Text('add a skill', style: Theme.of(ctx).textTheme.titleMedium),
            const Gap(6),
            Text(
              'any skill works — we embed it instantly. it starts at level 1 and '
              'levels up as you earn XP.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const Gap(16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                hintText: 'e.g. Public Speaking, Rust, Woodworking',
              ),
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
            ),
            const Gap(12),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Add skill'),
            ),
          ],
        ),
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      final skill = await ref.read(skillServiceProvider).addSkill(name.trim());
      ref.invalidate(mySkillsProvider);
      ref.invalidate(myProfileProvider);
      if (context.mounted) _snack(context, 'added ${skill.name} · Lv${skill.level}');
    } on SkillException catch (e) {
      if (context.mounted) _snack(context, e.message);
    } catch (_) {
      if (context.mounted) {
        _snack(context, "couldn't add skill — is the AI backend running?");
      }
    }
  }

  Future<void> _craftSkill(BuildContext context) async {
    final all = ref.read(mySkillsProvider).value ?? const <MySkill>[];
    final eligible = all.where((s) => s.level >= 3 && !s.isCompound).toList();
    if (eligible.length < 2) {
      _snack(context,
          'level up two skills to L3+ first — earn XP through collabs');
      return;
    }
    final selected = <String>{};
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('craft a compound skill',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const Gap(6),
              Text(
                'combine two or more mastered skills (L3+) into a new '
                'higher-order one. the more you fuse, the more senior it sounds.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const Gap(18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in eligible)
                    FilterChip(
                      label: Text('${s.name} · L${s.level}'),
                      selected: selected.contains(s.id),
                      showCheckmark: false,
                      backgroundColor: AppColors.bg,
                      selectedColor: AppColors.ink,
                      labelStyle: TextStyle(
                        color: selected.contains(s.id)
                            ? AppColors.onInk
                            : AppColors.text,
                        fontSize: 12,
                      ),
                      side: const BorderSide(color: AppColors.border),
                      onSelected: (v) => setLocal(() {
                        if (v) {
                          selected.add(s.id);
                        } else {
                          selected.remove(s.id);
                        }
                      }),
                    ),
                ],
              ),
              const Gap(20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selected.length >= 2
                      ? () => Navigator.of(ctx).pop(selected.toList())
                      : null,
                  child: Text(selected.length >= 2
                      ? 'Craft ⬡  (${selected.length})'
                      : 'pick at least 2 (${selected.length})'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || picked.length < 2 || !context.mounted) return;
    _snack(context, 'crafting…');
    try {
      final compound = await ref.read(skillServiceProvider).craft(picked);
      ref.invalidate(mySkillsProvider);
      ref.invalidate(myProfileProvider);
      if (context.mounted) _showCraftResult(context, compound);
    } on SkillException catch (e) {
      if (context.mounted) _snack(context, e.message);
    } catch (_) {
      if (context.mounted) {
        _snack(context, "couldn't craft — is the AI backend running?");
      }
    }
  }

  void _showCraftResult(BuildContext context, MySkill compound) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            const Icon(Icons.hub_rounded, color: AppColors.ink),
            const Gap(8),
            Expanded(
              child: Text(compound.name,
                  style: Theme.of(ctx).textTheme.titleLarge),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NEW COMPOUND SKILL · LV${compound.level}',
                style: AppTypography.mono(
                  fontSize: 9.5,
                  letterSpacing: 1.5,
                  color: AppColors.textMuted,
                )),
            if (compound.blurb?.isNotEmpty == true) ...[
              const Gap(12),
              Text(compound.blurb!,
                  style: Theme.of(ctx).textTheme.bodyMedium),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Nice'),
          ),
        ],
      ),
    );
  }

  Future<void> _editAvatar(BuildContext context, AvatarConfig current) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AvatarPickerScreen(initial: current),
      ),
    );
    if (changed == true) ref.invalidate(myProfileProvider);
  }

  Future<void> _editName(BuildContext context, String? current) async {
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
            Text('your name', style: Theme.of(ctx).textTheme.titleMedium),
            const Gap(6),
            Text(
              'this is how other builders see you.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const Gap(16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(hintText: 'e.g. Purvaj G'),
              onSubmitted: (_) => Navigator.of(ctx).pop(true),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && controller.text.trim().isNotEmpty) {
      await ref
          .read(profileRepositoryProvider)
          .updateDisplayName(controller.text.trim());
      ref.invalidate(myProfileProvider);
    }
  }

  Future<void> _editVibe(BuildContext context, String? current) async {
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

// ── Identity masthead ──────────────────────────────────────────────────────

class _Masthead extends StatelessWidget {
  const _Masthead({
    required this.avatar,
    required this.displayName,
    required this.username,
    required this.onEditAvatar,
    required this.onEditName,
  });

  final AvatarConfig avatar;
  final String? displayName;
  final String username;
  final VoidCallback onEditAvatar;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    final name =
        displayName?.isNotEmpty == true ? displayName! : '@$username';
    return Row(
      children: [
        GestureDetector(
          onTap: onEditAvatar,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              MeshAvatar(config: avatar, size: 92),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bg, width: 2),
                ),
                child: const Icon(Icons.edit, size: 13, color: AppColors.onInk),
              ),
            ],
          ),
        ),
        const Gap(18),
        Expanded(
          child: InkWell(
            onTap: onEditName,
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.display(
                          fontSize: 30,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ),
                    const Gap(8),
                    const Icon(Icons.edit_outlined,
                        size: 16, color: AppColors.textFaint),
                  ],
                ),
                if (displayName?.isNotEmpty == true) ...[
                  const Gap(2),
                  Text('@$username',
                      style: AppTypography.mono(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Three earned signals in one divided strip — not three identical cards.
class _StatStrip extends StatelessWidget {
  const _StatStrip({
    required this.reputation,
    required this.helps,
    required this.collabs,
  });

  final double reputation;
  final int helps;
  final int collabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _StatCell(value: reputation.toStringAsFixed(1), label: 'reputation'),
            const _StatDivider(),
            _StatCell(value: '$helps', label: 'helped'),
            const _StatDivider(),
            _StatCell(value: '$collabs', label: 'collabs'),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              const Gap(4),
              Text(label,
                  style: AppTypography.mono(fontSize: 9, letterSpacing: 1)),
            ],
          ),
        ),
      );
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) =>
      const VerticalDivider(width: 1, thickness: 1, color: AppColors.border);
}

/// The vibe as an editorial pull-quote rather than a generic bordered card.
class _VibePullquote extends StatelessWidget {
  const _VibePullquote({required this.vibe, required this.onEdit});
  final String? vibe;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasVibe = vibe?.isNotEmpty == true;
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('“',
                style: AppTypography.display(
                    fontSize: 44, color: AppColors.border)),
            const Gap(8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  hasVibe ? vibe! : 'add a vibe — what do you love building?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                        color: hasVibe ? AppColors.ink : AppColors.textFaint,
                        fontStyle:
                            hasVibe ? FontStyle.normal : FontStyle.italic,
                      ),
                ),
              ),
            ),
            const Gap(8),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Icon(Icons.edit_outlined,
                  size: 16, color: AppColors.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

/// A section header: title + helper microcopy + trailing actions, over a rule.
class _SectionHead extends StatelessWidget {
  const _SectionHead({
    required this.title,
    required this.caption,
    this.actions = const [],
  });

  final String title;
  final String caption;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            for (final a in actions) ...[a, const Gap(4)],
          ],
        ),
        const Gap(8),
        Container(height: 1, color: AppColors.border),
        const Gap(8),
        Text(caption,
            style: AppTypography.mono(fontSize: 9.5, letterSpacing: 0.4)),
      ],
    );
  }
}

class _ProofSection extends ConsumerWidget {
  const _ProofSection({required this.profile, required this.onConnect});

  final Map<String, dynamic> profile;
  final void Function(String id, String label, String? prefill) onConnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(connectedAccountsProvider).value ?? const {};
    final gh = profile['github_username'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHead(
          title: 'proof of skill',
          caption: 'connect accounts — real activity becomes verified, earned XP',
        ),
        const Gap(16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in _providers)
              _ProviderTile(
                label: p.label,
                connectedHandle: connected[p.id],
                soon: !p.active,
                onTap: p.active
                    ? () => onConnect(
                          p.id,
                          p.label,
                          p.id == 'github' ? gh : null,
                        )
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}

// ── Reusable bits ──────────────────────────────────────────────────────────

class _ShowMoreButton extends StatelessWidget {
  const _ShowMoreButton({
    required this.expanded,
    required this.hidden,
    required this.onTap,
  });

  final bool expanded;
  final int hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              expanded ? 'show less' : 'show $hidden more',
              style: AppTypography.mono(
                  color: AppColors.ink, letterSpacing: 0.4),
            ),
            const Gap(4),
            Icon(
              expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 18,
              color: AppColors.ink,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.component});
  final SkillComponent component;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            component.isCompound ? Icons.hub_rounded : Icons.circle,
            size: component.isCompound ? 13 : 6,
            color: AppColors.ink,
          ),
          const Gap(12),
          Expanded(
            child: Text(component.name,
                style: Theme.of(context).textTheme.bodyLarge),
          ),
          if (component.level != null)
            _Pips(level: component.level!)
          else
            Text('not yours',
                style: AppTypography.mono(fontSize: 9)),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.ink),
            const Gap(4),
            Text(
              label,
              style: AppTypography.mono(
                color: AppColors.ink,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A submitted portfolio entry — title, live/upload badge, and judged skills.
class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({required this.entry});

  final PortfolioEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entry.title,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              const Gap(8),
              Icon(
                entry.live ? Icons.verified_rounded : Icons.upload_file_rounded,
                size: 15,
                color: entry.live ? AppColors.ink : AppColors.textFaint,
              ),
              const Gap(4),
              Text(
                entry.live ? 'live' : 'upload',
                style: AppTypography.mono(
                  fontSize: 8.5,
                  letterSpacing: 1,
                  color: entry.live ? AppColors.ink : AppColors.textFaint,
                ),
              ),
            ],
          ),
          if (entry.skills.isNotEmpty) ...[
            const Gap(10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in entry.skills)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      s,
                      style: AppTypography.mono(
                        color: AppColors.ink,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A connectable provider tile in the "proof of skill" section.
class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.label,
    required this.soon,
    this.connectedHandle,
    this.onTap,
  });

  final String label;
  final bool soon;
  final String? connectedHandle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final connected = connectedHandle != null;
    return Opacity(
      opacity: soon ? 0.45 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: connected ? AppColors.ink : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                connected ? Icons.check_circle : Icons.link_rounded,
                size: 14,
                color: connected ? AppColors.onInk : AppColors.ink,
              ),
              const Gap(7),
              Text(
                connected ? '$label · @$connectedHandle' : label,
                style: AppTypography.mono(
                  fontSize: 12,
                  color: connected ? AppColors.onInk : AppColors.ink,
                  letterSpacing: 0.2,
                ),
              ),
              if (soon) ...[
                const Gap(6),
                Text(
                  'soon',
                  style: AppTypography.mono(fontSize: 8.5, letterSpacing: 1),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A skill chip with its earned level pips. Crafted compound skills are filled
/// (inked) with a node glyph and are tappable to reveal what they're made of.
class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.skill, this.onTap});

  final MySkill skill;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final compound = skill.isCompound;
    final fg = compound ? AppColors.onInk : AppColors.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: compound ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (compound) ...[
              Icon(Icons.hub_rounded, size: 13, color: fg),
              const Gap(6),
            ],
            Text(
              skill.name,
              style: AppTypography.mono(
                fontSize: 12.5,
                color: fg,
                letterSpacing: 0.2,
              ),
            ),
            if (skill.verified) ...[
              const Gap(6),
              Icon(Icons.verified, size: 14, color: fg),
            ],
            const Gap(8),
            _Pips(level: skill.level, onDark: compound),
            if (onTap != null) ...[
              const Gap(4),
              Icon(Icons.chevron_right_rounded, size: 15, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}

/// Five pips filled to [level] — the skill's earned mastery.
class _Pips extends StatelessWidget {
  const _Pips({required this.level, this.onDark = false});

  final int level;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final on = onDark ? AppColors.onInk : AppColors.ink;
    final off = onDark
        ? AppColors.onInk.withValues(alpha: 0.3)
        : AppColors.border;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++) ...[
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= level ? on : off,
            ),
          ),
          if (i < 5) const SizedBox(width: 2),
        ],
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Lets you point the app at the AI backend at runtime — paste a tunnel
/// (ngrok/cloudflared) or deployed URL on a real phone, no rebuild needed.
class _BackendSetting extends StatefulWidget {
  const _BackendSetting();
  @override
  State<_BackendSetting> createState() => _BackendSettingState();
}

class _BackendSettingState extends State<_BackendSetting> {
  Future<void> _edit() async {
    final controller =
        TextEditingController(text: ApiConfig.override ?? ApiConfig.baseUrl);
    final saved = await showModalBottomSheet<String?>(
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
            Text('AI backend URL', style: Theme.of(ctx).textTheme.titleMedium),
            const Gap(6),
            Text(
              'where the Groq engine lives (pitches, craft, portfolio). On a '
              'phone, paste your tunnel URL, e.g. https://abc.ngrok-free.app',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const Gap(16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                hintText: 'https://your-tunnel.ngrok-free.app',
              ),
            ),
            const Gap(12),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Save'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(''),
              child: const Text('Reset to default'),
            ),
          ],
        ),
      ),
    );
    if (saved == null) return; // dismissed
    await ApiConfig.setOverride(saved.isEmpty ? null : saved);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI backend → ${ApiConfig.baseUrl}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final custom = ApiConfig.override != null;
    return InkWell(
      onTap: _edit,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.cloud_outlined,
                size: 16,
                color: custom ? AppColors.ink : AppColors.textFaint),
            const Gap(8),
            Expanded(
              child: Text(
                'AI backend · ${Uri.parse(ApiConfig.baseUrl).host}',
                overflow: TextOverflow.ellipsis,
                style: AppTypography.mono(
                    fontSize: 10, letterSpacing: 0.3, color: AppColors.textMuted),
              ),
            ),
            const Icon(Icons.edit_outlined, size: 14, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}
