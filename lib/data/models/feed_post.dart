import 'avatar_config.dart';

class FeedPost {
  const FeedPost({
    required this.id,
    required this.channel,
    required this.body,
    required this.upvotes,
    required this.upvoted,
    required this.createdAt,
    required this.username,
    required this.displayName,
    required this.avatar,
    this.imageUrl,
  });

  final String id;
  final String channel;
  final String body;
  final int upvotes;
  final bool upvoted;
  final DateTime createdAt;
  final String username;
  final String? displayName;
  final AvatarConfig avatar;
  final String? imageUrl;

  String get authorName =>
      (displayName?.isNotEmpty == true) ? displayName! : '@$username';

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: json['id'] as String,
      channel: json['channel'] as String? ?? 'general',
      body: json['body'] as String? ?? '',
      upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
      upvoted: json['upvoted'] == true,
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String?,
      avatar: AvatarConfig.fromJson(
        json['avatar_config'] as Map<String, dynamic>?,
      ),
    );
  }
}

/// The channels available in the feed (the "servers").
const feedChannels = <String>[
  'general',
  'web-dev',
  'design',
  'ml',
  'music',
  'games',
  'makers',
];
