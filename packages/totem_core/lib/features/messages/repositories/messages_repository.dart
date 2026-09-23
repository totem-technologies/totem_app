import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/core/services/repository_utils.dart';
import 'package:totem_core/features/messages/models/conversation.dart';
import 'package:totem_core/features/messages/models/message.dart';
import 'package:totem_core/features/messages/models/message_pages.dart';

part 'messages_repository.g.dart';

abstract class MessagesRepository {
  Future<ConversationPage> getConversations({
    String? cursor,
    String? query,
    int? limit,
  });

  Future<Conversation> getConversation(String conversationId);

  Future<MessagePage> getMessages(
    String conversationId, {
    String? before,
    String? after,
    int? limit,
  });

  Future<Message> sendMessage(
    String conversationId,
    String text, {
    required String clientMessageId,
  });

  Future<void> markAsRead(String conversationId, String lastReadMessageId);

  Future<ConversationPage> syncConversations({String? since, int? limit});

  Future<Conversation> openConversation(String recipientSlug);

  Future<RecipientDirectorySchema> getRecipients({
    required RecipientDirectoryKind kind,
    String? query,
    String? cursor,
    int? limit,
  });

  Future<SessionParticipantPageSchema> getSessionParticipants(
    String sessionSlug, {
    String? cursor,
    int? limit,
  });

  Future<SessionMessageResultSchema> sendSessionMessage(
    String sessionSlug, {
    required List<String> recipientSlugs,
    required String text,
    required String clientRequestId,
  });
}

class ApiMessagesRepository implements MessagesRepository {
  ApiMessagesRepository(this._api);

  final ClientApi _api;

  @override
  Future<ConversationPage> getConversations({
    String? cursor,
    String? query,
    int? limit,
  }) async {
    final page = await RepositoryUtils.handleApiCall<ConversationPageSchema>(
      apiCall: () => _api.messages.totemMessagesMobileApiListConversations(
        cursor: cursor,
        query: query,
        limit: limit,
      ),
      operationName: 'list conversations',
      retryOnNetworkError: true,
    );
    return ConversationPage(
      items: page.items.map(_conversationFromSchema).toList(growable: false),
      nextCursor: page.nextCursor,
      totalUnreadCount: page.totalUnreadCount,
    );
  }

  @override
  Future<Conversation> getConversation(String conversationId) async {
    final conversation =
        await RepositoryUtils.handleApiCall<ConversationSummarySchema>(
          apiCall: () => _api.messages.totemMessagesMobileApiGetConversation(
            conversationId: conversationId,
          ),
          operationName: 'get conversation',
          diagnostics: {'conversation_id': conversationId},
        );
    return _conversationFromSchema(conversation);
  }

  @override
  Future<MessagePage> getMessages(
    String conversationId, {
    String? before,
    String? after,
    int? limit,
  }) async {
    final page = await RepositoryUtils.handleApiCall<MessagePageSchema>(
      apiCall: () => _api.messages.totemMessagesMobileApiListMessages(
        conversationId: conversationId,
        before: before,
        after: after,
        limit: limit,
      ),
      operationName: 'list conversation messages',
      retryOnNetworkError: true,
      diagnostics: {'conversation_id': conversationId},
    );
    return MessagePage(
      items: page.items
          .map((message) => _messageFromSchema(message, conversationId))
          .toList(growable: false),
      nextBefore: page.nextBefore,
      nextAfter: page.nextAfter,
      hasMore: page.hasMore,
    );
  }

  @override
  Future<Message> sendMessage(
    String conversationId,
    String text, {
    required String clientMessageId,
  }) async {
    final message = await RepositoryUtils.handleApiCall<MessageSchema>(
      apiCall: () => _api.messages.totemMessagesMobileApiSendMessage(
        conversationId: conversationId,
        body: SendMessageSchema(text: text, clientMessageId: clientMessageId),
      ),
      operationName: 'send message',
      diagnostics: {'conversation_id': conversationId},
    );
    return _messageFromSchema(message, conversationId);
  }

  @override
  Future<void> markAsRead(String conversationId, String lastReadMessageId) {
    return RepositoryUtils.handleApiCall<void>(
      apiCall: () => _api.messages.totemMessagesMobileApiMarkRead(
        conversationId: conversationId,
        body: MarkReadSchema(lastReadMessageId: lastReadMessageId),
      ),
      operationName: 'mark conversation read',
      diagnostics: {
        'conversation_id': conversationId,
        'last_read_message_id': lastReadMessageId,
      },
    );
  }

  @override
  Future<ConversationPage> syncConversations({
    String? since,
    int? limit,
  }) async {
    final page = await RepositoryUtils.handleApiCall<SyncPageSchema>(
      apiCall: () => _api.messages.totemMessagesMobileApiSyncMessages(
        since: since,
        limit: limit,
      ),
      operationName: 'sync conversations',
      retryOnNetworkError: true,
    );
    return ConversationPage(
      items: page.items.map(_conversationFromSchema).toList(growable: false),
      nextCursor: page.nextCursor,
      totalUnreadCount: page.totalUnreadCount,
    );
  }

  @override
  Future<Conversation> openConversation(String recipientSlug) async {
    final conversation =
        await RepositoryUtils.handleApiCall<ConversationSummarySchema>(
          apiCall: () => _api.messages.totemMessagesMobileApiOpenConversation(
            body: OpenConversationSchema(recipientSlug: recipientSlug),
          ),
          operationName: 'open conversation',
          diagnostics: {'recipient_slug': recipientSlug},
        );
    return _conversationFromSchema(conversation);
  }

  @override
  Future<RecipientDirectorySchema> getRecipients({
    required RecipientDirectoryKind kind,
    String? query,
    String? cursor,
    int? limit,
  }) {
    return RepositoryUtils.handleApiCall<RecipientDirectorySchema>(
      apiCall: () => _api.messages.totemMessagesMobileApiListRecipients(
        kind: kind,
        query: query,
        cursor: cursor,
        limit: limit,
      ),
      operationName: 'list message recipients',
      retryOnNetworkError: true,
      diagnostics: {'recipient_kind': kind.value},
    );
  }

  @override
  Future<SessionParticipantPageSchema> getSessionParticipants(
    String sessionSlug, {
    String? cursor,
    int? limit,
  }) {
    return RepositoryUtils.handleApiCall<SessionParticipantPageSchema>(
      apiCall: () =>
          _api.messages.totemMessagesMobileApiListSessionParticipants(
            sessionSlug: sessionSlug,
            cursor: cursor,
            limit: limit,
          ),
      operationName: 'list session message participants',
      retryOnNetworkError: true,
      diagnostics: {'session_slug': sessionSlug},
    );
  }

  @override
  Future<SessionMessageResultSchema> sendSessionMessage(
    String sessionSlug, {
    required List<String> recipientSlugs,
    required String text,
    required String clientRequestId,
  }) {
    return RepositoryUtils.handleApiCall<SessionMessageResultSchema>(
      apiCall: () => _api.messages.totemMessagesMobileApiSendSessionMessage(
        sessionSlug: sessionSlug,
        body: SendSessionMessagesSchema(
          recipientSlugs: recipientSlugs,
          text: text,
          clientRequestId: clientRequestId,
        ),
      ),
      operationName: 'send session message',
      diagnostics: {
        'session_slug': sessionSlug,
        'recipient_count': recipientSlugs.length,
      },
    );
  }

  static Conversation _conversationFromSchema(ConversationSummarySchema value) {
    return Conversation(
      id: value.id,
      peer: _publicUserFromPeer(value.peer),
      lastMessage: value.lastMessage == null
          ? null
          : Message(
              id: value.lastMessage!.id,
              conversationId: value.id,
              senderId: value.lastMessage!.senderSlug,
              text: value.lastMessage!.text,
              sentAt: value.lastMessage!.createdAt,
              isOwn: value.lastMessage!.isMine,
            ),
      unreadCount: value.unreadCount,
      updatedAt: value.updatedAt,
    );
  }

  static Message _messageFromSchema(
    MessageSchema value,
    String conversationId,
  ) {
    return Message(
      id: value.id,
      conversationId: conversationId,
      senderId: value.senderSlug,
      text: value.text,
      sentAt: value.createdAt,
      isOwn: value.isMine,
      clientMessageId: value.clientMessageId,
      cursor: value.cursor,
    );
  }

  static PublicUserSchema _publicUserFromPeer(MessagePeerSchema value) {
    return PublicUserSchema(
      profileAvatarType: value.profileAvatarType ?? ProfileAvatarTypeEnum.td,
      dateCreated: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      name: value.name,
      slug: value.slug,
      profileAvatarSeed: value.profileAvatarSeed,
      profileImage: value.profileImage,
    );
  }
}

@riverpod
MessagesRepository messagesRepository(Ref ref) =>
    ApiMessagesRepository(ref.watch(apiServiceProvider));
