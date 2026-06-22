import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(feedRepositoryProvider)
          .createPost(channel: _channel, body: body);
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
