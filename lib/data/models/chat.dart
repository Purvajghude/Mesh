import 'avatar_config.dart';

/// A match shown in the Crew (matches) list.
class ChatMatch {
  const ChatMatch({
    required this.matchId,
    required this.otherId,
    required this.username,
    required this.displayName,
    required this.avatar,
    required this.matchedAt,
    required this.lastMessage,
    required this.lastMessageAt,
  });

  final String matchId;
  final String otherId;
  final String username;
  final String? displayName;
  final AvatarConfig avatar;
  final DateTime matchedAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  String get name =>
      (displayName?.isNotEmpty == true) ? displayName! : '@$username';

  factory ChatMatch.fromJson(Map<String, dynamic> json) {
    return ChatMatch(
      matchId: json['match_id'] as String,
      otherId: json['other_id'] as String,
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String?,
      avatar: AvatarConfig.fromJson(
        json['avatar_config'] as Map<String, dynamic>?,
      ),
      matchedAt: DateTime.parse(json['matched_at'] as String),
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] == null
          ? null
          : DateTime.parse(json['last_message_at'] as String),
    );
  }
}

/// An emoji reaction on a message.
class Reaction {
  const Reaction({
    required this.messageId,
    required this.profileId,
    required this.emoji,
  });

  final String messageId;
  final String profileId;
  final String emoji;

  factory Reaction.fromJson(Map<String, dynamic> json) => Reaction(
        messageId: json['message_id'] as String,
        profileId: json['profile_id'] as String,
        emoji: json['emoji'] as String,
      );
}

/// Kinds of chat message.
enum MessageType { text, image, file, voice, call }

MessageType _typeFrom(String? s) => switch (s) {
      'image' => MessageType.image,
      'file' => MessageType.file,
      'voice' => MessageType.voice,
      'call' => MessageType.call,
      _ => MessageType.text,
    };

/// A single chat message (text, attachment, voice note, or call invite).
class Message {
  const Message({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.body,
    required this.type,
    required this.attachmentUrl,
    required this.attachmentMeta,
    required this.createdAt,
  });

  final String id;
  final String matchId;
  final String senderId;
  final String? body;
  final MessageType type;
  final String? attachmentUrl;
  final Map<String, dynamic>? attachmentMeta;
  final DateTime createdAt;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      matchId: json['match_id'] as String,
      senderId: json['sender_id'] as String,
      body: json['body'] as String?,
      type: _typeFrom(json['type'] as String?),
      attachmentUrl: json['attachment_url'] as String?,
      attachmentMeta: json['attachment_meta'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
