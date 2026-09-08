// GENERATED CODE - DO NOT MODIFY BY HAND

import 'dart:async';
import 'dart:convert';
import 'package:degenerate_runtime/degenerate_runtime.dart';
import '../models/conversation_page_schema.dart';
import '../models/conversation_summary_schema.dart';
import '../models/mark_read_schema.dart';
import '../models/message_page_schema.dart';
import '../models/message_schema.dart';
import '../models/open_conversation_schema.dart';
import '../models/recipient_directory_kind.dart';
import '../models/recipient_directory_schema.dart';
import '../models/send_message_schema.dart';
import '../models/send_session_messages_schema.dart';
import '../models/session_message_result_schema.dart';
import '../models/session_participant_page_schema.dart';
import '../models/sync_page_schema.dart';

/// MessagesApi operations.
///
/// All operations return [ApiResult] - use pattern matching to handle
/// success, error, and exception cases.
final class MessagesApi with ApiExecutor {
  const MessagesApi(this.apiConfig);

  @override
  final ApiConfig apiConfig;

  /// List Conversations
  ///
  /// `GET /api/mobile/protected/messages/conversations`
  Future<ApiResult<ConversationPageSchema, Never>>
  totemMessagesMobileApiListConversations({
    String? cursor,
    int? limit,
    RequestOptions? options,
  }) async {
    final queryParameters = <String, String>{
      ...apiConfig.defaultQueryParameters,
    };
    final queryParametersList = <ApiQueryParameter>[];
    if (cursor != null) {
      queryParameters['cursor'] = cursor;
    }
    if (limit != null) {
      queryParameters['limit'] = limit.toString();
    }

    final headers = <String, String>{...apiConfig.defaultHeaders};

    final request = ApiRequest(
      method: 'GET',
      path: '/api/mobile/protected/messages/conversations',
      headers: headers,
      queryParameters: queryParameters,
      queryParametersList: queryParametersList,
      options: options,
    );

    return execute(
      request,
      onSuccess: (response) {
        return ConversationPageSchema.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      },
    );
  }

  /// Open Conversation
  ///
  /// `POST /api/mobile/protected/messages/conversations`
  Future<ApiResult<ConversationSummarySchema, Never>>
  totemMessagesMobileApiOpenConversation({
    required OpenConversationSchema body,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};
    headers['Content-Type'] = 'application/json';

    final request = ApiRequest(
      method: 'POST',
      path: '/api/mobile/protected/messages/conversations',
      headers: headers,
      body: jsonEncode(body.toJson()),
      options: options,
    );

    return execute(
      request,
      onSuccess: (response) {
        return ConversationSummarySchema.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      },
    );
  }

  /// Get Conversation
  ///
  /// `GET /api/mobile/protected/messages/conversations/{conversation_id}`
  Future<ApiResult<ConversationSummarySchema, Never>>
  totemMessagesMobileApiGetConversation({
    required String conversationId,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};

    final request = ApiRequest(
      method: 'GET',
      path:
          '/api/mobile/protected/messages/conversations/${Uri.encodeComponent(conversationId)}',
      headers: headers,
      options: options,
    );

    return execute(
      request,
      onSuccess: (response) {
        return ConversationSummarySchema.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      },
    );
  }

  /// List Recipients
  ///
  /// Authorized 1:1 recipients; omit ``kind`` to prefer eligible keepers for dual-role users.
  ///
  /// The first ordered keepers page powers recommendations. Keepers composing to
  /// their own participants must explicitly request ``kind=participants``.
  ///
  /// `GET /api/mobile/protected/messages/recipients`
  Future<ApiResult<RecipientDirectorySchema, Never>>
  totemMessagesMobileApiListRecipients({
    RecipientDirectoryKind? kind,
    String? query,
    String? cursor,
    int? limit,
    RequestOptions? options,
  }) async {
    final queryParameters = <String, String>{
      ...apiConfig.defaultQueryParameters,
    };
    final queryParametersList = <ApiQueryParameter>[];
    if (kind != null) {
      queryParameters['kind'] = kind.toJson();
    }
    if (query != null) {
      queryParameters['query'] = query;
    }
    if (cursor != null) {
      queryParameters['cursor'] = cursor;
    }
    if (limit != null) {
      queryParameters['limit'] = limit.toString();
    }

    final headers = <String, String>{...apiConfig.defaultHeaders};

    final request = ApiRequest(
      method: 'GET',
      path: '/api/mobile/protected/messages/recipients',
      headers: headers,
      queryParameters: queryParameters,
      queryParametersList: queryParametersList,
      options: options,
    );

    return execute(
      request,
      onSuccess: (response) {
        return RecipientDirectorySchema.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      },
    );
  }

  /// List Messages
  ///
  /// `GET /api/mobile/protected/messages/conversations/{conversation_id}/messages`
  Future<ApiResult<MessagePageSchema, Never>>
  totemMessagesMobileApiListMessages({
    required String conversationId,
    String? before,
    String? after,
    int? limit,
    RequestOptions? options,
  }) async {
    final queryParameters = <String, String>{
      ...apiConfig.defaultQueryParameters,
    };
    final queryParametersList = <ApiQueryParameter>[];
    if (before != null) {
      queryParameters['before'] = before;
    }
    if (after != null) {
      queryParameters['after'] = after;
    }
    if (limit != null) {
      queryParameters['limit'] = limit.toString();
    }

    final headers = <String, String>{...apiConfig.defaultHeaders};

    final request = ApiRequest(
      method: 'GET',
      path:
          '/api/mobile/protected/messages/conversations/${Uri.encodeComponent(conversationId)}/messages',
      headers: headers,
      queryParameters: queryParameters,
      queryParametersList: queryParametersList,
      options: options,
    );

    return execute(
      request,
      onSuccess: (response) {
        return MessagePageSchema.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      },
    );
  }

  /// Send Message
  ///
  /// `POST /api/mobile/protected/messages/conversations/{conversation_id}/messages`
  Future<ApiResult<MessageSchema, Never>> totemMessagesMobileApiSendMessage({
    required String conversationId,
    required SendMessageSchema body,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};
    headers['Content-Type'] = 'application/json';

    final request = ApiRequest(
      method: 'POST',
      path:
          '/api/mobile/protected/messages/conversations/${Uri.encodeComponent(conversationId)}/messages',
      headers: headers,
      body: jsonEncode(body.toJson()),
      options: options,
    );

    return execute(
      request,
      onSuccess: (response) {
        return MessageSchema.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      },
    );
  }

  /// Mark Read
  ///
  /// `POST /api/mobile/protected/messages/conversations/{conversation_id}/read`
  Future<ApiResult<void, Never>> totemMessagesMobileApiMarkRead({
    required String conversationId,
    required MarkReadSchema body,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};
    headers['Content-Type'] = 'application/json';

    final request = ApiRequest(
      method: 'POST',
      path:
          '/api/mobile/protected/messages/conversations/${Uri.encodeComponent(conversationId)}/read',
      headers: headers,
      body: jsonEncode(body.toJson()),
      options: options,
    );

    return execute(request, onSuccess: (_) {});
  }

  /// Sync Messages
  ///
  /// `GET /api/mobile/protected/messages/sync`
  Future<ApiResult<SyncPageSchema, Never>> totemMessagesMobileApiSyncMessages({
    String? since,
    int? limit,
    RequestOptions? options,
  }) async {
    final queryParameters = <String, String>{
      ...apiConfig.defaultQueryParameters,
    };
    final queryParametersList = <ApiQueryParameter>[];
    if (since != null) {
      queryParameters['since'] = since;
    }
    if (limit != null) {
      queryParameters['limit'] = limit.toString();
    }

    final headers = <String, String>{...apiConfig.defaultHeaders};

    final request = ApiRequest(
      method: 'GET',
      path: '/api/mobile/protected/messages/sync',
      headers: headers,
      queryParameters: queryParameters,
      queryParametersList: queryParametersList,
      options: options,
    );

    return execute(
      request,
      onSuccess: (response) {
        return SyncPageSchema.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      },
    );
  }

  /// List Session Participants
  ///
  /// `GET /api/mobile/protected/messages/sessions/{session_slug}/participants`
  Future<ApiResult<SessionParticipantPageSchema, Never>>
  totemMessagesMobileApiListSessionParticipants({
    required String sessionSlug,
    String? cursor,
    int? limit,
    RequestOptions? options,
  }) async {
    final queryParameters = <String, String>{
      ...apiConfig.defaultQueryParameters,
    };
    final queryParametersList = <ApiQueryParameter>[];
    if (cursor != null) {
      queryParameters['cursor'] = cursor;
    }
    if (limit != null) {
      queryParameters['limit'] = limit.toString();
    }

    final headers = <String, String>{...apiConfig.defaultHeaders};

    final request = ApiRequest(
      method: 'GET',
      path:
          '/api/mobile/protected/messages/sessions/${Uri.encodeComponent(sessionSlug)}/participants',
      headers: headers,
      queryParameters: queryParameters,
      queryParametersList: queryParametersList,
      options: options,
    );

    return execute(
      request,
      onSuccess: (response) {
        return SessionParticipantPageSchema.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      },
    );
  }

  /// Send Session Message
  ///
  /// `POST /api/mobile/protected/messages/sessions/{session_slug}/messages`
  Future<ApiResult<SessionMessageResultSchema, Never>>
  totemMessagesMobileApiSendSessionMessage({
    required String sessionSlug,
    required SendSessionMessagesSchema body,
    RequestOptions? options,
  }) async {
    final headers = <String, String>{...apiConfig.defaultHeaders};
    headers['Content-Type'] = 'application/json';

    final request = ApiRequest(
      method: 'POST',
      path:
          '/api/mobile/protected/messages/sessions/${Uri.encodeComponent(sessionSlug)}/messages',
      headers: headers,
      body: jsonEncode(body.toJson()),
      options: options,
    );

    return execute(
      request,
      onSuccess: (response) {
        return SessionMessageResultSchema.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      },
    );
  }
}
