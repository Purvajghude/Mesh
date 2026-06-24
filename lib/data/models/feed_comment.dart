import 'avatar_config.dart';

/// A comment / answer on a feed post.
class FeedComment {
  const FeedComment({
    required this.id,
    required this.authorId,
    required this.body,
    required this.createdAt,
    required this.username,
    required this.displayName,
    required this.avatar,
  });

  final String id;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final String username;
  final String? displayName;
  final AvatarConfig avatar;

  String get authorName =>
      (displayName?.isNotEmpty == true) ? displayName! : '@$username';

  factory FeedComment.fromJson(Map<String, dynamic> json) => FeedComment(
        id: json['id'] as String,
        authorId: json['author_id'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
        username: json['username'] as String? ?? '',
        displayName: json['display_name'] as String?,
        avatar: AvatarConfig.fromJson(
          json['avatar_config'] as Map<String, dynamic>?,
        ),
      );
}
