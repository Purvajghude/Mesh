import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/avatar_config.dart';
import '../../../shared/widgets/mesh_avatar.dart';

/// Lets the user choose an avatar style and reroll the look. Saving writes the
/// new config to their profile. (Locking styles behind unlocks comes later.)
class AvatarPickerScreen extends ConsumerStatefulWidget {
  const AvatarPickerScreen({required this.initial, super.key});

  final AvatarConfig initial;

  @override
  ConsumerState<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends ConsumerState<AvatarPickerScreen> {
  late AvatarConfig _config = widget.initial;
  bool _busy = false;

  void _reroll() {
    final seed = (Random().nextDouble() * 1e9).toInt().toRadixString(16);
    setState(() => _config = _config.copyWith(seed: seed));
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).updateAvatar(_config);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't save avatar: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('your avatar'),
        actions: [
          IconButton(
            onPressed: _reroll,
            icon: const Icon(Icons.casino_rounded),
            tooltip: 'Reroll',
          ),
        ],
      ),
      body: Column(
        children: [
          const Gap(8),
          MeshAvatar(config: _config, size: 140),
          const Gap(8),
          Text('tap a style • 🎲 to reroll', style: textTheme.bodySmall),
          const Gap(16),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: AvatarConfig.styles.length,
              itemBuilder: (context, i) {
                final style = AvatarConfig.styles[i];
                final selected = style == _config.style;
                final preview = _config.copyWith(style: style);
                return GestureDetector(
                  onTap: () => setState(() => _config = preview),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? AppColors.ink : AppColors.border,
                        width: selected ? 2 : 1,
                      ),
                      color: AppColors.surface,
                    ),
                    child: Center(
                      child: MeshAvatar(config: preview, size: 72),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save avatar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
