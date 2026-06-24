import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/wallet.dart';
import '../../../shared/widgets/mesh_avatar.dart';
import '../application/bank_providers.dart';
import 'post_request_sheet.dart';

/// The credit economy: your wallet, the open help-request board, and your own
/// requests. Credits are conserved — helping moves them, it never mints them.
class BankScreen extends ConsumerWidget {
  const BankScreen({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(walletProvider);
    ref.invalidate(helpBoardProvider);
    ref.invalidate(myRequestsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);
    final boardAsync = ref.watch(helpBoardProvider);
    final mineAsync = ref.watch(myRequestsProvider);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            children: [
              walletAsync.when(
                loading: () => const _WalletSkeleton(),
                error: (e, _) => Text('Could not load wallet: $e'),
                data: (w) => _WalletCard(
                  wallet: w,
                  onClaim: () => _claim(context, ref),
                ),
              ),
              const Gap(28),
              const _SectionHeader(
                title: 'open requests',
                caption: 'someone needs a hand — help and earn their credits',
              ),
              const Gap(14),
              boardAsync.when(
                loading: () => const _Loading(),
                error: (e, _) => Text('Could not load the board: $e'),
                data: (board) {
                  if (board.isEmpty) {
                    return const _EmptyNote(
                      'no open requests right now. post one below — '
                      'or check back when the campus is buzzing.',
                    );
                  }
                  return Column(
                    children: [
                      for (final r in board)
                        _BoardCard(
                          request: r,
                          onAccept: () => _accept(context, ref, r),
                        ),
                    ],
                  );
                },
              ),
              const Gap(28),
              const _SectionHeader(
                title: 'your requests',
                caption: 'what you owe and are owed',
              ),
              const Gap(14),
              mineAsync.when(
                loading: () => const _Loading(),
                error: (e, _) => Text('Could not load your requests: $e'),
                data: (mine) {
                  if (mine.isEmpty) {
                    return const _EmptyNote(
                      'you have no active requests. tap “ask for help”.',
                    );
                  }
                  return Column(
                    children: [
                      for (final r in mine)
                        _MyRequestCard(
                          request: r,
                          onConfirm: () => _confirm(context, ref, r),
                          onCancel: () => _cancel(context, ref, r),
                        ),
                    ],
                  );
                },
              ),
              const Gap(20),
              Center(
                child: Text(
                  'XP is who you are · credits are what you owe and are owed',
                  textAlign: TextAlign.center,
                  style: AppTypography.mono(fontSize: 9.5, letterSpacing: 0.6),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: ElevatedButton.icon(
            onPressed: () => _post(context, ref),
            icon: const Icon(Icons.add_rounded, color: AppColors.onInk),
            label: const Text('ask for help'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    try {
      final bal = await ref.read(economyRepositoryProvider).claimGrant();
      _refresh(ref);
      if (context.mounted) {
        _snack(context, 'claimed 5 starter credits · balance $bal ◇');
      }
    } catch (e) {
      if (context.mounted) _snack(context, _clean(e));
    }
  }

  Future<void> _post(BuildContext context, WidgetRef ref) async {
    final posted = await showPostRequestSheet(context, ref);
    if (posted == true) _refresh(ref);
  }

  Future<void> _accept(
      BuildContext context, WidgetRef ref, BoardRequest r) async {
    final ok = await _confirmDialog(
      context,
      title: 'accept this request?',
      body: 'you’ll help ${r.requesterName} with “${r.title}”. '
          'their ${r.credits} ◇ are held in escrow until they confirm '
          'you delivered.',
      action: 'Accept',
    );
    if (ok != true) return;
    try {
      await ref.read(economyRepositoryProvider).accept(r.id);
      _refresh(ref);
      if (context.mounted) _snack(context, 'accepted · ${r.credits} ◇ in escrow');
    } catch (e) {
      if (context.mounted) _snack(context, _clean(e));
    }
  }

  Future<void> _confirm(
      BuildContext context, WidgetRef ref, MyRequest r) async {
    final ok = await _confirmDialog(
      context,
      title: 'confirm delivery?',
      body: 'this releases ${r.credits} ◇ to ${r.otherName} and logs their '
          'XP. only do this once they’ve actually helped.',
      action: 'Confirm & pay',
    );
    if (ok != true) return;
    try {
      await ref.read(economyRepositoryProvider).confirm(r.id);
      _refresh(ref);
      if (context.mounted) _snack(context, 'released ${r.credits} ◇ to ${r.otherName}');
    } catch (e) {
      if (context.mounted) _snack(context, _clean(e));
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, MyRequest r) async {
    try {
      await ref.read(economyRepositoryProvider).cancel(r.id);
      _refresh(ref);
      if (context.mounted) _snack(context, 'request cancelled');
    } catch (e) {
      if (context.mounted) _snack(context, _clean(e));
    }
  }

  Future<bool?> _confirmDialog(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: Text(body, style: Theme.of(ctx).textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Postgres surfaces RPC errors with noise; show just the human message.
  String _clean(Object e) {
    final s = e.toString();
    final m = RegExp(r'[A-Za-z].*$').firstMatch(s.split(':').last.trim());
    return m?.group(0) ?? 'something went wrong';
  }
}

// ── Wallet ──────────────────────────────────────────────────────────────────

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.wallet, required this.onClaim});

  final Wallet wallet;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CREDIT BALANCE',
            style: AppTypography.mono(
              fontSize: 10,
              letterSpacing: 2,
              color: AppColors.onInkFaint,
            ),
          ),
          const Gap(10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${wallet.balance}',
                style: AppTypography.display(
                  fontSize: 64,
                  color: AppColors.onInk,
                  letterSpacing: -3,
                ),
              ),
              const Gap(8),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '◇ credits',
                  style: AppTypography.mono(
                    fontSize: 13,
                    color: AppColors.onInkFaint,
                  ),
                ),
              ),
            ],
          ),
          if (wallet.escrowed > 0) ...[
            const Gap(4),
            Text(
              '${wallet.escrowed} ◇ held in escrow on your accepted requests',
              style: AppTypography.mono(
                fontSize: 10.5,
                letterSpacing: 0.3,
                color: AppColors.onInkFaint,
              ),
            ),
          ],
          if (!wallet.claimed) ...[
            const Gap(18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onClaim,
                icon: const Icon(Icons.card_giftcard_rounded,
                    size: 18, color: AppColors.onInk),
                label: const Text('claim 5 starter credits'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onInk,
                  side: const BorderSide(color: AppColors.onInkFaint),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WalletSkeleton extends StatelessWidget {
  const _WalletSkeleton();
  @override
  Widget build(BuildContext context) => Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.onInkFaint),
        ),
      );
}

// ── Cards ───────────────────────────────────────────────────────────────────

class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.request, required this.onAccept});

  final BoardRequest request;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: request.urgent ? AppColors.danger : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MeshAvatar(config: request.avatar, size: 34),
              const Gap(10),
              Expanded(
                child: Text(request.requesterName,
                    style: textTheme.titleSmall),
              ),
              if (request.urgent) ...[
                const _UrgentBadge(),
                const Gap(8),
              ],
              _CreditPill(credits: request.credits),
            ],
          ),
          const Gap(12),
          Text(request.title,
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          if (request.description?.isNotEmpty == true) ...[
            const Gap(4),
            Text(request.description!, style: textTheme.bodyMedium),
          ],
          const Gap(12),
          Row(
            children: [
              if (request.skillName != null) ...[
                _MetaChip(label: request.skillName!),
                const Gap(8),
              ],
              _MetaChip(label: _sizeLabel(request.size)),
              const Spacer(),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: const Text('I’ll help'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MyRequestCard extends StatelessWidget {
  const _MyRequestCard({
    required this.request,
    required this.onConfirm,
    required this.onCancel,
  });

  final MyRequest request;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final r = request;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.title,
                    style: textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              const Gap(8),
              _CreditPill(credits: r.credits),
            ],
          ),
          const Gap(8),
          Row(
            children: [
              _StatusChip(status: r.status),
              const Gap(8),
              Text(
                r.isRequester
                    ? (r.status == 'accepted'
                        ? '${r.otherName} is helping'
                        : 'you asked')
                    : 'helping ${r.otherName}',
                style: AppTypography.mono(fontSize: 10, letterSpacing: 0.3),
              ),
            ],
          ),
          // Requester confirms once the helper delivers.
          if (r.isRequester && r.status == 'accepted') ...[
            const Gap(12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onConfirm,
                child: Text('confirm & release ${r.credits} ◇'),
              ),
            ),
          ],
          // Requester can withdraw a still-open request.
          if (r.isRequester && r.status == 'open') ...[
            const Gap(8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
                child: const Text('cancel'),
              ),
            ),
          ],
          // Helper waiting on confirmation.
          if (!r.isRequester && r.status == 'accepted') ...[
            const Gap(8),
            Text(
              'deliver the help, then ${r.otherName} confirms to release your '
              'credits.',
              style: textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Small bits ──────────────────────────────────────────────────────────────

class _CreditPill extends StatelessWidget {
  const _CreditPill({required this.credits});
  final int credits;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$credits ◇',
          style: AppTypography.mono(
            fontSize: 12,
            color: AppColors.onInk,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _UrgentBadge extends StatelessWidget {
  const _UrgentBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'URGENT',
          style: AppTypography.mono(
            fontSize: 8.5,
            color: AppColors.onInk,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppTypography.mono(
              fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.3),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final filled = status == 'accepted' || status == 'confirmed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? AppColors.ink : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: AppTypography.mono(
          fontSize: 9.5,
          letterSpacing: 1,
          color: filled ? AppColors.onInk : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.caption});
  final String title;
  final String caption;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Gap(4),
          Text(caption,
              style: AppTypography.mono(fontSize: 9.5, letterSpacing: 0.5)),
        ],
      );
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
}

String _sizeLabel(String size) => switch (size) {
      'quick' => 'quick · ~30m',
      'deep' => 'deep · ~half-day',
      _ => 'standard · ~1–2h',
    };
