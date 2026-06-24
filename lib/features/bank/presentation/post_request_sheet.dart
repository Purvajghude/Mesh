import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/my_skill.dart';
import '../../../data/models/wallet.dart';
import '../../profile/application/profile_providers.dart';

/// Bottom sheet to post a help request. Returns true if a request was created.
Future<bool?> showPostRequestSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _PostSheet(),
  );
}

class _PostSheet extends ConsumerStatefulWidget {
  const _PostSheet();
  @override
  ConsumerState<_PostSheet> createState() => _PostSheetState();
}

class _PostSheetState extends ConsumerState<_PostSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _size = 'standard';
  bool _urgent = false;
  String? _skillId;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  /// Mirror the server-side price (base × urgency premium, capped at 12).
  int get _price {
    final base = requestSizes.firstWhere((s) => s.key == _size).base;
    final raw = (base * (_urgent ? 1.5 : 1.0)).round();
    return raw.clamp(1, 12);
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(economyRepositoryProvider).post(
            title: title,
            description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
            skillId: _skillId,
            size: _size,
            urgent: _urgent,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        final msg = e.toString().split(':').last.trim();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final skills = ref.watch(mySkillsProvider).value ?? const <MySkill>[];
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ask for help', style: textTheme.titleMedium),
            const Gap(4),
            Text(
              'pick a size — the cost is held in escrow when someone accepts, '
              'and released when you confirm they helped.',
              style: AppTypography.mono(fontSize: 9.5, letterSpacing: 0.4),
            ),
            const Gap(16),
            TextField(
              controller: _title,
              autofocus: true,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                hintText: 'what do you need? e.g. debug my Firebase auth',
              ),
            ),
            const Gap(10),
            TextField(
              controller: _desc,
              maxLines: 2,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                hintText: 'a little more detail (optional)',
              ),
            ),
            const Gap(18),
            Text('SIZE',
                style: AppTypography.mono(
                    fontSize: 9, letterSpacing: 1.5, color: AppColors.textMuted)),
            const Gap(8),
            for (final s in requestSizes)
              _SizeRow(
                label: s.label,
                hint: s.hint,
                base: s.base,
                selected: _size == s.key,
                onTap: () => setState(() => _size = s.key),
              ),
            const Gap(14),
            if (skills.isNotEmpty) ...[
              Text('SKILL (optional — helper earns XP in it)',
                  style: AppTypography.mono(
                      fontSize: 9,
                      letterSpacing: 1.2,
                      color: AppColors.textMuted)),
              const Gap(8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in skills.take(12))
                    ChoiceChip(
                      label: Text(s.name),
                      selected: _skillId == s.id,
                      showCheckmark: false,
                      backgroundColor: AppColors.bg,
                      selectedColor: AppColors.ink,
                      labelStyle: TextStyle(
                        color: _skillId == s.id
                            ? AppColors.onInk
                            : AppColors.text,
                        fontSize: 12,
                      ),
                      side: const BorderSide(color: AppColors.border),
                      onSelected: (v) =>
                          setState(() => _skillId = v ? s.id : null),
                    ),
                ],
              ),
              const Gap(14),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _urgent,
              activeThumbColor: AppColors.danger,
              onChanged: (v) => setState(() => _urgent = v),
              title: const Text('urgent'),
              subtitle: Text(
                'jumps the queue · +50% (it costs more so it stays honest)',
                style: textTheme.bodySmall,
              ),
            ),
            const Gap(8),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onInk),
                    )
                  : Text('post · $_price ◇'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeRow extends StatelessWidget {
  const _SizeRow({
    required this.label,
    required this.hint,
    required this.base,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String hint;
  final int base;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? AppColors.onInk : AppColors.textMuted,
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? AppColors.onInk : AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    hint,
                    style: AppTypography.mono(
                      fontSize: 9.5,
                      letterSpacing: 0.2,
                      color: selected
                          ? AppColors.onInkFaint
                          : AppColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'from $base ◇',
              style: AppTypography.mono(
                color: selected ? AppColors.onInk : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
