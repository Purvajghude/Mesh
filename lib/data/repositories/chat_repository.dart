import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat.dart';
import '../services/supabase_service.dart';

/// Matches list, realtime messages, attachments, and collab logging.
class ChatRepository {
  const ChatRepository();

  Future<List<ChatMatch>> getMatches() async {
    final rows =
        await SupabaseService.client.rpc('get_matches') as List<dynamic>;
    return [
      for (final r in rows) ChatMatch.fromJson(r as Map<String, dynamic>),
    ];
  }

  /// Live stream of messages for a match, oldest first.
  Stream<List<Message>> messagesStream(String matchId) {
    return SupabaseService.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .order('created_at', ascending: true)
        .map((rows) => [for (final r in rows) Message.fromJson(r)]);
  }

  Future<void> sendMessage({
    required String matchId,
    required String body,
    MessageType type = MessageType.text,
    Map<String, dynamic>? meta,
  }) async {
    final me = SupabaseService.currentUser!.id;
    await SupabaseService.client.from('messages').insert({
      'match_id': matchId,
      'sender_id': me,
      'body': body.trim(),
      'type': type.name,
      'attachment_meta': ?meta,
    });
  }

  /// Uploads bytes to the chat-media bucket and posts an attachment message.
  Future<void> sendAttachment({
    required String matchId,
    required Uint8List bytes,
    required String filename,
    required MessageType type,
    String? mime,
    Map<String, dynamic>? meta,
  }) async {
    final me = SupabaseService.currentUser!.id;
    final safe = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '$matchId/${DateTime.now().millisecondsSinceEpoch}_$safe';

    await SupabaseService.client.storage.from('chat-media').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime),
        );
    final url =
        SupabaseService.client.storage.from('chat-media').getPublicUrl(path);

    await SupabaseService.client.from('messages').insert({
      'match_id': matchId,
      'sender_id': me,
      'type': type.name,
      'attachment_url': url,
      'attachment_meta': {...?meta, 'filename': filename},
    });
  }

  Future<void> logCollab({
    required String matchId,
    required String title,
    String? description,
    List<String>? skillIds,
  }) async {
    await SupabaseService.client.rpc('log_collab', params: {
      'p_match': matchId,
      'p_title': title,
      'p_description': description,
      'p_skill_ids': skillIds,
    });
  }

  /// The skills a collab can be tagged with — the union of both participants'
  /// skills. Tagging a skill awards both members XP in it (earned expertise).
  Future<List<({String id, String name})>> collabSkillOptions(
    String matchId,
  ) async {
    final rows = await SupabaseService.client
        .rpc('collab_skill_options', params: {'p_match': matchId})
        as List<dynamic>;
    return [
      for (final r in rows)
        (id: r['id'] as String, name: r['name'] as String),
    ];
  }

  /// Live stream of all reactions in a match.
  Stream<List<Reaction>> reactionsStream(String matchId) {
    return SupabaseService.client
        .from('message_reactions')
        .stream(primaryKey: ['message_id', 'profile_id', 'emoji'])
        .eq('match_id', matchId)
        .map((rows) => [for (final r in rows) Reaction.fromJson(r)]);
  }

  Future<void> toggleReaction({
    required String messageId,
    required String emoji,
  }) async {
    await SupabaseService.client.rpc('toggle_reaction', params: {
      'p_message': messageId,
      'p_emoji': emoji,
    });
  }

  /// Starts a call by posting a 'call' message carrying a Jitsi room link that
  /// both participants can open. [video] toggles video vs audio-only.
  /// Returns the room URL so the caller can join immediately.
  Future<String> startCall({
    required String matchId,
    required bool video,
  }) async {
    final me = SupabaseService.currentUser!.id;
    final room =
        'mesh-${matchId.replaceAll('-', '').substring(0, 12)}-${DateTime.now().millisecondsSinceEpoch}';
    final url = video
        ? 'https://meet.jit.si/$room'
        : 'https://meet.jit.si/$room#config.startWithVideoMuted=true';
    await SupabaseService.client.from('messages').insert({
      'match_id': matchId,
      'sender_id': me,
      'type': 'call',
      'body': video ? '📹 started a video call' : '📞 started a voice call',
      'attachment_url': url,
      'attachment_meta': {'video': video},
    });
    return url;
  }
}
