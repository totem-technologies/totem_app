import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/models/profile_avatar_type_enum.dart';
import 'package:totem_core/core/api/api_client/models/public_user_schema.dart';
import 'package:uuid/uuid.dart';

import '../models/conversation.dart';
import '../models/message.dart';

part 'messages_repository.g.dart';

abstract class MessagesRepository {
  Future<List<Conversation>> getConversations();

  Future<List<Message>> getMessages(
    String conversationId, {
    String? beforeId,
  });

  Future<Message> sendMessage(String conversationId, String text);

  Future<void> markAsRead(String conversationId);
}

// ---------------------------------------------------------------------------
// Stub implementation – replace with a real API-backed class once the backend
// messages endpoints are available.
// ---------------------------------------------------------------------------
class _StubMessagesRepository implements MessagesRepository {
  static final _now = DateTime.now();

  static final _peers = <String, PublicUserSchema>{
    'conv_1': PublicUserSchema(
      profileAvatarType: ProfileAvatarTypeEnum.td,
      dateCreated: _now,
      name: 'Vanessa',
      slug: 'vanessa',
      profileAvatarSeed: 'vanessa-seed',
    ),
    'conv_2': PublicUserSchema(
      profileAvatarType: ProfileAvatarTypeEnum.td,
      dateCreated: _now,
      name: 'Marcus',
      slug: 'marcus',
      profileAvatarSeed: 'marcus-seed',
    ),
    'conv_3': PublicUserSchema(
      profileAvatarType: ProfileAvatarTypeEnum.td,
      dateCreated: _now,
      name: 'Sarah',
      slug: 'sarah',
      profileAvatarSeed: 'sarah-seed',
    ),
    'conv_4': PublicUserSchema(
      profileAvatarType: ProfileAvatarTypeEnum.td,
      dateCreated: _now,
      name: 'Jordan',
      slug: 'jordan',
      profileAvatarSeed: 'jordan-seed',
    ),
    'conv_5': PublicUserSchema(
      profileAvatarType: ProfileAvatarTypeEnum.td,
      dateCreated: _now,
      name: 'Alex',
      slug: 'alex',
      profileAvatarSeed: 'alex-seed',
    ),
  };

  static Message _msg(
    String convId,
    String text, {
    required int minutesAgo,
    required bool isOwn,
  }) {
    return Message(
      id: const Uuid().v4(),
      conversationId: convId,
      senderId: isOwn ? 'me' : convId,
      text: text,
      sentAt: _now.subtract(Duration(minutes: minutesAgo)),
      isOwn: isOwn,
    );
  }

  static final _threads = <String, List<Message>>{
    'conv_1': [
      _msg(
        'conv_1',
        'That really means a lot to me, thank you for sharing',
        minutesAgo: 1,
        isOwn: false,
      ),
      _msg(
        'conv_1',
        "I hear you. I've been there so many times. You're not alone, I promise.",
        minutesAgo: 2,
        isOwn: false,
      ),
      _msg(
        'conv_1',
        "Honestly, today's been tough. But talking helps. It's nice not to feel alone in it.",
        minutesAgo: 4,
        isOwn: true,
      ),
      _msg(
        'conv_1',
        'Totally. Some days are harder than others. How are you doing today?',
        minutesAgo: 7,
        isOwn: false,
      ),
      _msg(
        'conv_1',
        "Hi Vanessa! Thanks for reaching out. It's nice to connect with someone who gets it.",
        minutesAgo: 10,
        isOwn: true,
      ),
      _msg(
        'conv_1',
        'Hey! I saw your profile and I think we have a lot in common.',
        minutesAgo: 12,
        isOwn: false,
      ),
    ],
    'conv_2': [
      _msg(
        'conv_2',
        "I'll check in with you tomorrow",
        minutesAgo: 60,
        isOwn: true,
      ),
    ],
    'conv_3': [
      _msg(
        'conv_3',
        'Take care of yourself this weekend',
        minutesAgo: 1440,
        isOwn: true,
      ),
    ],
    'conv_4': [
      _msg(
        'conv_4',
        '3 months sober today! Wanted to share...',
        minutesAgo: 2880,
        isOwn: false,
      ),
    ],
    'conv_5': [
      _msg(
        'conv_5',
        'Let me know if you ever want to talk again',
        minutesAgo: 4320,
        isOwn: false,
      ),
    ],
  };

  @override
  Future<List<Conversation>> getConversations() async {
    return _peers.entries.map((entry) {
      final convId = entry.key;
      final peer = entry.value;
      final messages = _threads[convId] ?? [];
      final last = messages.isNotEmpty ? messages.first : null;
      return Conversation(
        id: convId,
        peer: peer,
        lastMessage: last,
        unreadCount: convId == 'conv_1' ? 2 : 0,
        updatedAt: last?.sentAt ?? _now,
      );
    }).toList();
  }

  @override
  Future<List<Message>> getMessages(
    String conversationId, {
    String? beforeId,
  }) async {
    final messages = _threads[conversationId] ?? [];
    if (beforeId == null) return messages;
    final idx = messages.indexWhere((m) => m.id == beforeId);
    if (idx == -1) return [];
    return messages.sublist(idx + 1);
  }

  @override
  Future<Message> sendMessage(String conversationId, String text) async {
    final message = Message(
      id: const Uuid().v4(),
      conversationId: conversationId,
      senderId: 'me',
      text: text,
      sentAt: DateTime.now(),
      isOwn: true,
      status: MessageStatus.sent,
    );
    _threads.putIfAbsent(conversationId, () => []).insert(0, message);
    return message;
  }

  @override
  Future<void> markAsRead(String conversationId) async {}
}

@riverpod
MessagesRepository messagesRepository(Ref ref) => _StubMessagesRepository();
