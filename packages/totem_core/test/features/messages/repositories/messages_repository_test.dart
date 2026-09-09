import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/messages/repositories/messages_repository.dart';

final class _RecordingApiClient implements ApiClient {
  _RecordingApiClient(this.responseFor);

  final ApiResponse Function(ApiRequest request) responseFor;
  final requests = <ApiRequest>[];

  @override
  Uri get baseUrl => Uri.parse('https://example.test');

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    return responseFor(request);
  }

  @override
  Future<StreamedApiResponse> sendStreaming(ApiRequest request) =>
      throw UnimplementedError();

  @override
  Future<void> close() async {}
}

Map<String, dynamic> _peerJson() => <String, dynamic>{
  'slug': 'peer',
  'name': 'Peer',
  'profile_image': null,
  'profile_avatar_seed': 'seed',
  'profile_avatar_type': 'TD',
};

Map<String, dynamic> _messageJson({
  String id = 'message-1',
  String? clientMessageId,
  bool isMine = false,
}) => <String, dynamic>{
  'id': id,
  'sender_id': 1,
  'sender_slug': isMine ? 'me' : 'peer',
  'text': 'Hello',
  'client_message_id': clientMessageId,
  'created_at': '2026-09-08T12:00:00Z',
  'cursor': 'message-cursor',
  'is_mine': isMine,
};

void main() {
  group('ApiMessagesRepository', () {
    test('maps inbox, keyset page, send and read requests', () async {
      final client = _RecordingApiClient((request) {
        if (request.path.endsWith('/conversations')) {
          return ApiResponse(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'items': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'conversation-1',
                  'peer': _peerJson(),
                  'last_message': <String, dynamic>{
                    'id': 'message-1',
                    'sender_slug': 'peer',
                    'text': 'Hello',
                    'created_at': '2026-09-08T12:00:00Z',
                    'is_mine': false,
                  },
                  'unread_count': 1,
                  'updated_at': '2026-09-08T12:00:00Z',
                },
              ],
              'next_cursor': null,
              'total_unread_count': 1,
            }),
          );
        }
        if (request.method == 'GET') {
          return ApiResponse(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'items': <Map<String, dynamic>>[_messageJson()],
              'next_before': 'opaque-before',
              'next_after': 'opaque-after',
              'has_more': true,
            }),
          );
        }
        if (request.method == 'POST' && request.path.endsWith('/read')) {
          return ApiResponse(statusCode: 204, body: '');
        }
        return ApiResponse(
          statusCode: 200,
          body: jsonEncode(
            _messageJson(
              id: 'canonical',
              clientMessageId: 'client-1',
              isMine: true,
            ),
          ),
        );
      });
      final repository = ApiMessagesRepository(
        ClientApi(ApiConfig(client: client)),
      );

      final inbox = await repository.getConversations(limit: 20, query: 'peer');
      final page = await repository.getMessages(
        'conversation-1',
        before: 'opaque-before',
      );
      final sent = await repository.sendMessage(
        'conversation-1',
        'Hello',
        clientMessageId: 'client-1',
      );
      await repository.markAsRead('conversation-1', 'message-1');

      expect(inbox.items.single.peer.slug, 'peer');
      expect(inbox.items.single.unreadCount, 1);
      expect(client.requests.first.queryParameters['query'], 'peer');
      expect(page.hasMore, isTrue);
      expect(page.nextBefore, 'opaque-before');
      expect(sent.id, 'canonical');
      expect(sent.clientMessageId, 'client-1');
      expect(client.requests[1].queryParameters['before'], 'opaque-before');
      expect(jsonDecode(client.requests[2].body! as String), <String, dynamic>{
        'text': 'Hello',
        'client_message_id': 'client-1',
      });
      expect(jsonDecode(client.requests[3].body! as String), <String, dynamic>{
        'last_read_message_id': 'message-1',
      });
    });

    test(
      'opens a direct conversation using the public recipient slug',
      () async {
        final client = _RecordingApiClient(
          (_) => ApiResponse(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'id': 'conversation-1',
              'peer': _peerJson(),
              'last_message': null,
              'unread_count': 0,
              'updated_at': '2026-09-08T12:00:00Z',
            }),
          ),
        );
        final repository = ApiMessagesRepository(
          ClientApi(ApiConfig(client: client)),
        );

        final conversation = await repository.openConversation('peer');

        expect(conversation.id, 'conversation-1');
        expect(client.requests.single.method, 'POST');
        expect(
          jsonDecode(client.requests.single.body! as String),
          <String, dynamic>{'recipient_slug': 'peer'},
        );
      },
    );
  });
}
