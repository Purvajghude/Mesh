import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/chat.dart';
import '../../../data/models/chat_background.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/services/supabase_service.dart';
import '../../../shared/widgets/mesh_avatar.dart';
import '../../profile/application/profile_providers.dart';
import '../application/chat_providers.dart';

/// One-on-one realtime chat with a matched user: text, images, files, and
/// (in later phases) voice notes + calls.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.match, super.key});

  final ChatMatch match;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await _repo.sendMessage(matchId: widget.match.matchId, body: text);
    } catch (e) {
      if (mounted) {
        _controller.text = text;
        _snack("Couldn't send: $e");
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attach() async {
    final choice = await showModalBottomSheet<_Attach>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_rounded, color: AppColors.ink),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(ctx, _Attach.image),
            ),
            ListTile(
              leading: const Icon(
                Icons.insert_drive_file_rounded,
                color: AppColors.ink,
              ),
              title: const Text('File'),
              onTap: () => Navigator.pop(ctx, _Attach.file),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    final isImage = choice == _Attach.image;
    final group = isImage
        ? const XTypeGroup(
            label: 'images',
            extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
          )
        : const XTypeGroup(label: 'files');
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;

    setState(() => _sending = true);
    try {
      final bytes = await file.readAsBytes();
      await _repo.sendAttachment(
        matchId: widget.match.matchId,
        bytes: bytes,
        filename: file.name,
        type: isImage ? MessageType.image : MessageType.file,
        mime: file.mimeType ?? _mimeFromName(file.name),
        meta: {'size': bytes.length},
      );
    } catch (e) {
      if (mounted) _snack("Couldn't upload: $e");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _uploadBackground() async {
    const group = XTypeGroup(
      label: 'images',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      await ref.read(profileRepositoryProvider).uploadCustomChatBg(
            bytes: bytes,
            filename: file.name,
            mime: file.mimeType ?? _mimeFromName(file.name),
          );
      ref.invalidate(myProfileProvider);
      if (mounted) _snack('background updated');
    } catch (e) {
      if (mounted) _snack("Couldn't set background: $e");
    }
  }

  void _pickBackground() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'chat background',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const Gap(16),
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _uploadBackground();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined,
                          color: AppColors.ink),
                      const Gap(12),
                      Text('Upload your own',
                          style: Theme.of(ctx).textTheme.titleSmall),
                    ],
                  ),
                ),
              ),
              const Gap(18),
              Text(
                'OR PICK A WASH',
                style: AppTypography.mono(
                    fontSize: 9, letterSpacing: 1.5, color: AppColors.textMuted),
              ),
              const Gap(14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final bg in chatBackgrounds)
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await ref
                            .read(profileRepositoryProvider)
                            .updateChatBg(bg.key);
                        ref.invalidate(myProfileProvider);
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 96,
                            decoration: BoxDecoration(
                              gradient: bg.gradient,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: bg.premium
                                ? const Align(
                                    alignment: Alignment.topRight,
                                    child: Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.auto_awesome,
                                        size: 14,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const Gap(6),
                          Text(
                            bg.name,
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReactionPicker(String messageId) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final e in const ['👍', '🔥', '😂', '❤️', '🎉', '🙌', '🤝'])
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _repo.toggleReaction(messageId: messageId, emoji: e);
                  },
                  child: Text(e, style: const TextStyle(fontSize: 34)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logCollab() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    // Skills the collab can be tagged with — tagging awards both of you XP.
    List<({String id, String name})> options = const [];
    try {
      options = await _repo.collabSkillOptions(widget.match.matchId);
    } catch (_) {
      // proceed without skill tagging if it can't load
    }
    if (!mounted) return;
    final selected = <String>{};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('log a collab'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: AppColors.text),
                    decoration: const InputDecoration(
                      hintText: 'what are you building?',
                    ),
                  ),
                  const Gap(12),
                  TextField(
                    controller: descController,
                    style: const TextStyle(color: AppColors.text),
                    decoration:
                        const InputDecoration(hintText: 'details (optional)'),
                  ),
                  if (options.isNotEmpty) ...[
                    const Gap(18),
                    Text(
                      'SKILLS YOU USED — you both level up',
                      style: AppTypography.mono(
                        fontSize: 9,
                        letterSpacing: 1.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const Gap(10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final o in options)
                          FilterChip(
                            label: Text(o.name),
                            selected: selected.contains(o.id),
                            showCheckmark: false,
                            backgroundColor: AppColors.bg,
                            selectedColor: AppColors.ink,
                            labelStyle: TextStyle(
                              color: selected.contains(o.id)
                                  ? AppColors.onInk
                                  : AppColors.text,
                              fontSize: 12,
                            ),
                            side: const BorderSide(color: AppColors.border),
                            onSelected: (v) => setLocal(() {
                              if (v) {
                                selected.add(o.id);
                              } else {
                                selected.remove(o.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Start collab'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && titleController.text.trim().isNotEmpty) {
      await _repo.logCollab(
        matchId: widget.match.matchId,
        title: titleController.text.trim(),
        description: descController.text.trim().isEmpty
            ? null
            : descController.text.trim(),
        skillIds: selected.isEmpty ? null : selected.toList(),
      );
      if (mounted) {
        _snack(selected.isEmpty
            ? 'collab started 🚀'
            : 'collab logged 🚀 +XP in ${selected.length} '
                'skill${selected.length > 1 ? "s" : ""}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.match.matchId));
    final reactions =
        ref.watch(reactionsProvider(widget.match.matchId)).asData?.value ??
        const {};
    final profile = ref.watch(myProfileProvider).asData?.value;
    final myBg = profile?['chat_bg'] as String?;
    final customBgUrl = profile?['chat_bg_url'] as String?;
    final useCustom = myBg == 'custom' && customBgUrl != null;
    final bg = backgroundForKey(myBg);
    final me = SupabaseService.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            MeshAvatar(config: widget.match.avatar, size: 36),
            const Gap(12),
            Text(widget.match.name),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _pickBackground,
            icon: const Icon(Icons.wallpaper_rounded),
            tooltip: 'Background',
          ),
          IconButton(
            onPressed: _logCollab,
            icon: const Icon(Icons.handshake_rounded),
            tooltip: 'Log a collab',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: useCustom ? null : bg.gradient,
          image: useCustom
              ? DecorationImage(
                  image: NetworkImage(customBgUrl),
                  fit: BoxFit.cover,
                  // Wash the photo toward paper so message bubbles stay legible.
                  colorFilter: ColorFilter.mode(
                    AppColors.bg.withValues(alpha: 0.55),
                    BlendMode.lighten,
                  ),
                )
              : null,
        ),
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Could not load chat: $e')),
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'say hi to ${widget.match.name} 👋',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  }
                  final reversed = messages.reversed.toList();
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: reversed.length,
                    itemBuilder: (context, i) {
                      final msg = reversed[i];
                      return _MessageRow(
                        message: msg,
                        mine: msg.senderId == me,
                        reactions: reactions[msg.id] ?? const [],
                        onLongPress: () => _showReactionPicker(msg.id),
                      );
                    },
                  );
                },
              ),
            ),
            _Composer(
              controller: _controller,
              sending: _sending,
              onSend: _send,
              onAttach: _attach,
            ),
          ],
        ),
      ),
    );
  }
}

enum _Attach { image, file }

/// A message bubble plus its reaction chips, with long-press to react.
class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.mine,
    required this.reactions,
    required this.onLongPress,
  });

  final Message message;
  final bool mine;
  final List<Reaction> reactions;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    return Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onLongPress: onLongPress,
          child: _Bubble(message: message, mine: mine),
        ),
        if (counts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Wrap(
              spacing: 4,
              children: [
                for (final e in counts.entries)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '${e.key} ${e.value}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});

  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final color = mine ? AppColors.ink : AppColors.surface;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    );

    Widget content;
    switch (message.type) {
      case MessageType.image:
        content = ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            message.attachmentUrl!,
            width: 220,
            fit: BoxFit.cover,
            loadingBuilder: (c, child, p) => p == null
                ? child
                : const SizedBox(
                    width: 220,
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  ),
          ),
        );
      case MessageType.file:
        content = _FileChip(message: message, mine: mine);
      case MessageType.call:
        content = _CallCard(message: message, mine: mine);
      case MessageType.text:
      case MessageType.voice:
        content = Text(
          message.body ?? '',
          style: TextStyle(color: mine ? AppColors.onInk : AppColors.text),
        );
    }

    final isImage = message.type == MessageType.image;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: isImage
          ? const EdgeInsets.all(4)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: mine ? null : Border.all(color: AppColors.border),
      ),
      child: content,
    );
  }
}

/// A call invite bubble with a Join button.
class _CallCard extends StatelessWidget {
  const _CallCard({required this.message, required this.mine});

  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final video = message.attachmentMeta?['video'] == true;
    final fg = mine ? AppColors.onInk : AppColors.text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(video ? Icons.videocam_rounded : Icons.call_rounded, color: fg),
        const Gap(10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              video ? 'Video call' : 'Voice call',
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
            GestureDetector(
              onTap: () {
                final url = message.attachmentUrl;
                if (url != null) {
                  launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
              child: Text(
                'tap to join →',
                style: TextStyle(
                  color: mine ? AppColors.onInk : AppColors.ink,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.message, required this.mine});

  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final name = message.attachmentMeta?['filename'] as String? ?? 'file';
    final fg = mine ? AppColors.onInk : AppColors.ink;
    return GestureDetector(
      onTap: () {
        final url = message.attachmentUrl;
        if (url != null) launchUrl(Uri.parse(url));
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_rounded, color: fg),
          const Gap(8),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: sending ? null : onAttach,
              icon: const Icon(Icons.add_circle_outline_rounded),
              color: AppColors.textMuted,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: AppColors.text),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'message…',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const Gap(8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                ),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onInk,
                        ),
                      )
                    : const Icon(
                        Icons.arrow_upward_rounded,
                        color: AppColors.onInk,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _mimeFromName(String name) {
  final ext = name.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    _ => 'application/octet-stream',
  };
}
