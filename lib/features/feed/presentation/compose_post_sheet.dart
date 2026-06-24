import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/feed_post.dart';
import '../../../data/models/my_skill.dart';
import '../../profile/application/profile_providers.dart';
import '../application/feed_providers.dart';

Future<void> showComposePostSheet(BuildContext context, WidgetRef ref,
    {FeedKind initialKind = FeedKind.show}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ComposeSheet(initialKind: initialKind),
  );
}

class _ComposeSheet extends ConsumerStatefulWidget {
  const _ComposeSheet({required this.initialKind});
  final FeedKind initialKind;

  @override
  ConsumerState<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends ConsumerState<_ComposeSheet> {
  final _controller = TextEditingController();
  late FeedKind _kind = widget.initialKind;
  final _tags = <String>{};
  bool _busy = false;
  Uint8List? _imageBytes;
  String? _imageName;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final shot = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (shot == null) return;
    final bytes = await shot.readAsBytes();
    if (mounted) {
      setState(() {
        _imageBytes = bytes;
        _imageName = shot.name;
      });
    }
  }

  Future<void> _post() async {
    final body = _controller.text.trim();
    if ((body.isEmpty && _imageBytes == null) || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(feedRepositoryProvider).createPost(
            kind: _kind,
            body: body,
            skillTags: _tags.toList(),
            imageBytes: _imageBytes,
            imageName: _imageName,
          );
      ref.invalidate(feedProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't post: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final skills = ref.watch(mySkillsProvider).value ?? const <MySkill>[];
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
            // Kind picker — the post's purpose.
            Wrap(
              spacing: 8,
              children: [
                for (final k in FeedKind.values)
                  ChoiceChip(
                    label: Text(k.label),
                    selected: _kind == k,
                    showCheckmark: false,
                    backgroundColor: AppColors.bg,
                    selectedColor: AppColors.ink,
                    labelStyle: TextStyle(
                      color: _kind == k ? AppColors.onInk : AppColors.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                    side: const BorderSide(color: AppColors.border),
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ],
            ),
            const Gap(16),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 4,
              maxLength: 400,
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(hintText: _kind.prompt),
            ),
            if (_imageBytes != null) ...[
              const Gap(4),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    Image.memory(
                      _imageBytes!,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _imageBytes = null;
                          _imageName = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.ink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 18, color: AppColors.onInk),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (skills.isNotEmpty) ...[
              const Gap(14),
              Text(
                _kind == FeedKind.ask
                    ? 'WHAT SKILLS WOULD HELP?'
                    : 'SKILLS INVOLVED',
                style: AppTypography.mono(
                    fontSize: 9, color: AppColors.textMuted),
              ),
              const Gap(8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in skills.take(12))
                    FilterChip(
                      label: Text(s.name),
                      selected: _tags.contains(s.name),
                      showCheckmark: false,
                      backgroundColor: AppColors.bg,
                      selectedColor: AppColors.ink,
                      labelStyle: TextStyle(
                        color: _tags.contains(s.name)
                            ? AppColors.onInk
                            : AppColors.text,
                        fontSize: 12,
                      ),
                      side: const BorderSide(color: AppColors.border),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _tags.add(s.name);
                        } else {
                          _tags.remove(s.name);
                        }
                      }),
                    ),
                ],
              ),
            ],
            const Gap(12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _busy ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined,
                      size: 18, color: AppColors.ink),
                  label: Text(
                    _imageBytes == null ? 'add a photo' : 'change photo',
                    style: AppTypography.mono(
                        color: AppColors.ink, letterSpacing: 0.4),
                  ),
                ),
                const Spacer(),
              ],
            ),
            const Gap(4),
            ElevatedButton(
              onPressed: _busy ? null : _post,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_kind == FeedKind.ask ? 'Post ask' : 'Post'),
            ),
          ],
        ),
      ),
    );
  }
}
