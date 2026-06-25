import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_typography.dart';
import '../../../data/services/push_service.dart';
import '../../../data/services/supabase_service.dart';
import '../../chat/presentation/crew_screen.dart';
import '../../feed/presentation/feed_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../profile/presentation/search_screen.dart';
import '../../swipe/presentation/swipe_deck_screen.dart';

/// Bottom-nav shell. The feed-of-helpers puts the community **Feed** at home;
/// the complementarity swipe deck is demoted to **Discover**; Crew is your
/// matches/chats; You is your profile.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  // index 0 (feed) shows the wordmark; the rest show their title.
  static const _titles = ['mesh', 'discover', 'crew', 'you'];

  @override
  void initState() {
    super.initState();
    // We're signed in by the time the shell mounts → register for push.
    PushService.register();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _index == 0 ? 'mesh' : _titles[_index],
          style: _index == 0
              ? AppTypography.display(fontSize: 26, letterSpacing: -1.2)
              : Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          if (_index == 0 || _index == 1)
            IconButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SearchScreen(),
              )),
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Search builders',
            ),
          if (_index == 3)
            IconButton(
              onPressed: () async {
                await PushService.unregister();
                await SupabaseService.auth.signOut();
              },
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Sign out',
            ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          FeedScreen(),
          SwipeDeckScreen(),
          CrewScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.diversity_3_outlined),
            selectedIcon: Icon(Icons.diversity_3),
            label: 'Crew',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'You',
          ),
        ],
      ),
    );
  }
}
