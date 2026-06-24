import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_typography.dart';
import '../../../data/services/supabase_service.dart';
import '../../bank/presentation/bank_screen.dart';
import '../../chat/presentation/crew_screen.dart';
import '../../feed/presentation/feed_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../swipe/presentation/swipe_deck_screen.dart';

/// Bottom-nav shell. Discover (swipe deck) and Feed are placeholders until
/// their tasks; the "You" tab is the live profile screen.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _titles = ['discover', 'crew', 'feed', 'bank', 'you'];

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
          if (_index == 4)
            IconButton(
              onPressed: () => SupabaseService.auth.signOut(),
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Sign out',
            ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          SwipeDeckScreen(),
          CrewScreen(),
          FeedScreen(),
          BankScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
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
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Bank',
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
