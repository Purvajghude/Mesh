import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/models/feed_post.dart';

/// Currently selected channel filter (null = all channels).
class SelectedChannelNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? channel) => state = channel;
}

final selectedChannelProvider =
    NotifierProvider<SelectedChannelNotifier, String?>(
  SelectedChannelNotifier.new,
);

/// Feed posts for the selected channel.
final feedProvider = FutureProvider<List<FeedPost>>((ref) {
  final channel = ref.watch(selectedChannelProvider);
  return ref.watch(feedRepositoryProvider).getFeed(channel: channel);
});
