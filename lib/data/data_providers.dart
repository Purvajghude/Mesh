import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/chat_repository.dart';
import 'repositories/economy_repository.dart';
import 'repositories/feed_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/swipe_repository.dart';
import 'services/github_service.dart';
import 'services/integration_service.dart';
import 'services/portfolio_service.dart';
import 'services/skill_service.dart';

/// Shared data-layer singletons used across features.
final githubServiceProvider = Provider<GithubService>((ref) => GithubService());

final skillServiceProvider = Provider<SkillService>((ref) => SkillService());

final integrationServiceProvider =
    Provider<IntegrationService>((ref) => IntegrationService());

final portfolioServiceProvider =
    Provider<PortfolioService>((ref) => PortfolioService());

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => const ProfileRepository());

final swipeRepositoryProvider =
    Provider<SwipeRepository>((ref) => const SwipeRepository());

final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => const ChatRepository());

final feedRepositoryProvider =
    Provider<FeedRepository>((ref) => const FeedRepository());

final economyRepositoryProvider =
    Provider<EconomyRepository>((ref) => const EconomyRepository());
