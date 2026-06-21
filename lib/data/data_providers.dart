import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/chat_repository.dart';
import 'repositories/feed_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/swipe_repository.dart';
import 'services/github_service.dart';

/// Shared data-layer singletons used across features.
final githubServiceProvider = Provider<GithubService>((ref) => GithubService());

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => const ProfileRepository());

final swipeRepositoryProvider =
    Provider<SwipeRepository>((ref) => const SwipeRepository());

final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => const ChatRepository());

final feedRepositoryProvider =
    Provider<FeedRepository>((ref) => const FeedRepository());
