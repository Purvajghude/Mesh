import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/search_result.dart';
import '../../../shared/widgets/mesh_avatar.dart';
import 'public_profile_screen.dart';

/// Find builders by name or by a skill they have (e.g. "@purvaj" or "react").
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  List<SearchResult> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(value));
  }

  Future<void> _run(String value) async {
    final q = value.trim();
    setState(() => _query = q);
    if (q.length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      // Try semantic search first; fall back to text search if backend is down.
      final semantic = await repo.searchProfilesSemantic(q);
      final res = semantic ?? await repo.searchProfiles(q);
      if (mounted && _controller.text.trim() == q) {
        setState(() {
          _results = res;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: const TextStyle(color: AppColors.text, fontSize: 16),
          onChanged: _onChanged,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'search builders or skills…',
          ),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _controller.clear();
                _run('');
              },
            ),
        ],
      ),
      body: _body(textTheme),
    );
  }

  Widget _body(TextTheme textTheme) {
    if (_query.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'find a builder by name, or by a skill you need —\ntry "design", "rust", or a username.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return Center(
        child: Text('no builders found for “$_query”.',
            style: textTheme.bodyMedium),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Gap(8),
      itemBuilder: (context, i) => _ResultTile(result: _results[i]),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});
  final SearchResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    // Subtitle prefers the matched skill ("knows React"), else helping stats.
    final subtitle = r.matchedSkill != null
        ? 'knows ${r.matchedSkill}'
        : (r.helpsCount > 0 ? '${r.helpsCount} builders helped' : '@${r.username}');
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PublicProfileScreen(userId: r.id),
      )),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            MeshAvatar(config: r.avatar, size: 42),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name, style: Theme.of(context).textTheme.titleSmall),
                  const Gap(2),
                  Text(subtitle, style: AppTypography.mono(fontSize: 10.5)),
                ],
              ),
            ),
            if (r.helpKarma > 0) ...[
              const Icon(Icons.volunteer_activism_rounded,
                  size: 14, color: AppColors.textMuted),
              const Gap(4),
              Text('${r.helpKarma}',
                  style: AppTypography.mono(color: AppColors.textMuted)),
            ],
          ],
        ),
      ),
    );
  }
}
