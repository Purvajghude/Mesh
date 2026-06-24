import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/feed_post.dart';
import '../application/feed_providers.dart';

Future<void> showComposePostSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ComposeSheet(),
  );
}

class _ComposeSheet extends ConsumerStatefulWidget {
  const _ComposeSheet();

  @override
  ConsumerState<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends ConsumerState<_ComposeSheet> {
  final _controller = TextEditingController();
  String _channel = feedChannels.first;
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
            channel: _channel,
            body: body,
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
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('share an update',
              style: Theme.of(context).textTheme.titleMedium),
          const Gap(16),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: feedChannels.length,
              separatorBuilder: (_, _) => const Gap(8),
              itemBuilder: (context, i) {
                final c = feedChannels[i];
                final sel = c == _channel;
                return GestureDetector(
                  onTap: () => setState(() => _channel = c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? AppColors.ink : AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: sel ? AppColors.ink : AppColors.border,
                      ),
                    ),
                    child: Text(
                      '#$c',
                      style: TextStyle(
                        color: sel ? AppColors.onInk : AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Gap(16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 4,
            maxLength: 280,
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(
              hintText: 'what did you build / what are you looking for?',
            ),
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
          const Gap(8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy ? null : _pickImage,
              icon: const Icon(Icons.image_outlined,
                  size: 18, color: AppColors.ink),
              label: Text(
                _imageBytes == null ? 'add a photo' : 'change photo',
                style: AppTypography.mono(
                    color: AppColors.ink, letterSpacing: 0.4),
              ),
            ),
          ),
          const Gap(8),
          ElevatedButton(
            onPressed: _busy ? null : _post,
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Post'),
          ),
        ],
      ),
    );
  }
}
