import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/messages/models/conversation.dart';
import 'package:totem_core/features/messages/models/message.dart';
import 'package:totem_core/features/messages/models/message_pages.dart';
import 'package:totem_core/features/messages/providers/thread_provider.dart';
import 'package:totem_core/features/messages/repositories/messages_repository.dart';

final class _FakeMessagesRepository implements MessagesRepository {
  _FakeMessagesRepository({required this.failFirstSend});

  final bool failFirstSend;
  final sentClientIds = <String>[];
  var _sendAttempts = 0;
  String? before;

  @override
  Future<MessagePage> getMessages(
    String conversationId, {
    String? before,
    String? after,
    int? limit,
  }) async {
    this.before = before;
    if (before == null) {
      return MessagePage(
        items: [
          Message(
            id: 'new',
            conversationId: conversationId,
            senderId: 'peer',
            text: 'Newest',
            sentAt: DateTime(2026, 9, 8, 12),
          ),
          Message(
            id: 'old',
            conversationId: conversationId,
            senderId: 'peer',
            text: 'Old',
            sentAt: DateTime(2026, 9, 8, 11),
          ),
        ],
        nextBefore: 'opaque-before',
        hasMore: true,
      );
    }
    return MessagePage(
      items: [
        Message(
          id: 'older',
          conversationId: conversationId,
          senderId: 'peer',
          text: 'Older',
          sentAt: DateTime(2026, 9, 8, 10),
        ),
      ],
      hasMore: false,
    );
  }

  @override
  Future<Message> sendMessage(
    String conversationId,
    String text, {
    required String clientMessageId,
  }) async {
    sentClientIds.add(clientMessageId);
    _sendAttempts++;
    if (failFirstSend && _sendAttempts == 1) throw Exception('offline');
    return Message(
      id: 'canonical',
      conversationId: conversationId,
      senderId: 'me',
      text: text,
      sentAt: DateTime(2026, 9, 8, 13),
      isOwn: true,
      clientMessageId: clientMessageId,
    );
  }

  @override
  Future<ConversationPage> getConversations({String? cursor, int? limit}) =>
      throw UnimplementedError();

  @override
  Future<Conversation> getConversation(String conversationId) =>
      throw UnimplementedError();

  @override
  Future<void> markAsRead(
    String conversationId,
    String lastReadMessageId,
  ) async {}

  @override
  Future<Conversation> openConversation(String recipientSlug) =>
      throw UnimplementedError();

  @override
  Future<SessionParticipantPageSchema> getSessionParticipants(
    String sessionSlug, {
    String? cursor,
    int? limit,
  }) => throw UnimplementedError();

  @override
  Future<ConversationPage> syncConversations({String? since, int? limit}) =>
      throw UnimplementedError();

  @override
  Future<RecipientDirectorySchema> getRecipients({
    required RecipientDirectoryKind kind,
    String? query,
    String? cursor,
    int? limit,
  }) => throw UnimplementedError();

  @override
  Future<SessionMessageResultSchema> sendSessionMessage(
    String sessionSlug, {
    required List<String> recipientSlugs,
    required String text,
    required String clientRequestId,
  }) => throw UnimplementedError();
}

void main() {
  test('paginates once and keeps retry client ids stable', () async {
    final repository = _FakeMessagesRepository(failFirstSend: true);
    final container = ProviderContainer(
      overrides: [messagesRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(threadProvider('conversation-1').future);
    await container.read(threadProvider('conversation-1').notifier).loadMore();
    var thread = container.read(threadProvider('conversation-1')).requireValue;
    expect(repository.before, 'opaque-before');
    expect(thread.messages.map((message) => message.id), [
      'new',
      'old',
      'older',
    ]);

    expect(
      await container
          .read(threadProvider('conversation-1').notifier)
          .send('Hi'),
      isFalse,
    );
    thread = container.read(threadProvider('conversation-1')).requireValue;
    final failed = thread.messages.firstWhere(
      (message) => message.status == MessageStatus.failed,
    );
    expect(
      await container
          .read(threadProvider('conversation-1').notifier)
          .retry(failed),
      isTrue,
    );
    thread = container.read(threadProvider('conversation-1')).requireValue;
    expect(thread.messages.first.id, 'canonical');
    expect(repository.sentClientIds[0], repository.sentClientIds[1]);
  });
}
