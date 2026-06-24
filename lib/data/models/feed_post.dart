import 'avatar_config.dart';

class FeedPost {
  const FeedPost({
    required this.id,
    required this.kind,
    required this.authorId,
    required this.body,
    required this.upvotes,
    required this.upvoted,
    required this.createdAt,
    required this.username,
    required this.displayName,
    required this.avatar,
    this.skillTags = const [],
    this.status,
    this.imageUrl,
    this.commentCount = 0,
    this.aiAnswer,
    this.matchScore = 0,
  });

  final String id;
  final FeedKind kind;
  final String authorId;
  final String body;
  final List<String> skillTags;
  final String? status; // asks only: open | answered | solved
  final int upvotes;
  final bool upvoted;
  final int commentCount;
  final String? aiAnswer; // AI first-pass on an ask
  final int matchScore; // how many of the post's tags the viewer has proven
  final DateTime createdAt;
  final String username;
  final String? displayName;
  final AvatarConfig avatar;
  final String? imageUrl;

  String get authorName =>
      (displayName?.isNotEmpty == true) ? displayName! : '@$username';

  bool get isAsk => kind == FeedKind.ask;
  bool get solved => status == 'solved';

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: json['id'] as String,
      kind: FeedKind.from(json['kind'] as String?),
      authorId: json['author_id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      skillTags: [
        for (final t in (json['skill_tags'] as List? ?? const [])) t as String,
      ],
      status: json['status'] as String?,
      upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
      upvoted: json['upvoted'] == true,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      aiAnswer: json['ai_answer'] as String?,
      matchScore: (json['match_score'] as num?)?.toInt() ?? 0,
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

/// The four kinds of feed post in the builder community.
enum FeedKind {
  ask, // a blocker — "stuck on X"
  show, // shipped work — "built this"
  offer, // a helper advertising capacity
  buildlog; // a progress update

  static FeedKind from(String? s) => switch (s) {
        'ask' => FeedKind.ask,
        'offer' => FeedKind.offer,
        'buildlog' => FeedKind.buildlog,
        _ => FeedKind.show,
      };

  String get label => switch (this) {
        FeedKind.ask => 'Ask',
        FeedKind.show => 'Show',
        FeedKind.offer => 'Offer',
        FeedKind.buildlog => 'Build log',
      };

  /// Composer prompt for this kind.
  String get prompt => switch (this) {
        FeedKind.ask => "what's blocking you?",
        FeedKind.show => 'what did you build?',
        FeedKind.offer => 'what can you help with?',
        FeedKind.buildlog => "what's the latest on your build?",
      };
}
