import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/core/services/api_service.dart';

import '../../setup.dart';

final class _RecordingApiClient implements ApiClient {
  _RecordingApiClient(this.response);

  final ApiResponse response;
  ApiRequest? request;
  var requestCount = 0;

  @override
  Uri get baseUrl => Uri.parse('https://example.com');

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    this.request = request;
    requestCount++;
    return response;
  }

  @override
  Future<StreamedApiResponse> sendStreaming(ApiRequest request) {
    throw UnimplementedError('Streaming is not used by these tests');
  }

  @override
  Future<void> close() async {}
}

Map<String, dynamic> _sessionJson({
  required String slug,
  required String title,
  required bool attending,
}) {
  return <String, dynamic>{
    'slug': slug,
    'title': title,
    'space': <String, dynamic>{
      'slug': '$slug-space',
      'title': '$title Space',
      'image_link': null,
      'short_description': 'A test space',
      'content': '',
      'author': <String, dynamic>{
        'profile_avatar_type': 'TD',
        'date_created': '2026-01-01T00:00:00Z',
      },
      'category': null,
      'subscribers': 1,
      'recurring': null,
      'price': 0,
      'next_events': <dynamic>[],
    },
    'content': '',
    'seats_left': 5,
    'duration': 60,
    'start': '2026-08-20T15:00:00Z',
    'attending': attending,
    'open': true,
    'started': false,
    'cancelled': false,
    'joinable': false,
    'ended': false,
    'rsvp_url': '/rsvp/$slug',
    'join_url': null,
    'subscribe_url': '/subscribe/$slug',
    'cal_link': '/calendar/$slug',
    'subscribed': true,
    'user_timezone': 'UTC',
    'meeting_provider': 'livekit',
  };
}

ProviderContainer _containerFor(_RecordingApiClient client) {
  return ProviderContainer(
    overrides: [
      apiServiceProvider.overrideWithValue(
        ClientApi(ApiConfig(client: client)),
      ),
    ],
  );
}

void main() {
  setUpAll(() {
    setupAppConfig();
    silenceLogger();
  });

  group('RSVP repository', () {
    test('returns attendance status when RSVP succeeds', () async {
      final client = _RecordingApiClient(
        ApiResponse(
          statusCode: 200,
          body: jsonEncode(
            _sessionJson(
              slug: 'new-session',
              title: 'New Session',
              attending: true,
            ),
          ),
        ),
      );
      final container = _containerFor(client);
      addTearDown(container.dispose);

      final attending = await container.read(
        rsvpConfirmProvider('new-session').future,
      );

      expect(attending, isTrue);
      expect(client.request?.method, 'POST');
      expect(
        client.request?.path,
        '/api/mobile/protected/spaces/rsvp/new-session',
      );
    });

    test('exposes the existing session when RSVP conflicts', () async {
      final client = _RecordingApiClient(
        ApiResponse(
          statusCode: 409,
          body: jsonEncode(
            _sessionJson(
              slug: 'existing-session',
              title: 'Existing Session',
              attending: true,
            ),
          ),
        ),
      );
      final container = _containerFor(client);
      addTearDown(container.dispose);

      await expectLater(
        container.read(rsvpConfirmProvider('new-session').future),
        throwsA(
          isA<RsvpConflictException>().having(
            (error) => error.conflictingSession.slug,
            'conflicting session slug',
            'existing-session',
          ),
        ),
      );
      expect(client.requestCount, 1);
    });

    test('switches from the conflicting session to the new session', () async {
      final client = _RecordingApiClient(
        ApiResponse(
          statusCode: 200,
          body: jsonEncode(
            _sessionJson(
              slug: 'new-session',
              title: 'New Session',
              attending: true,
            ),
          ),
        ),
      );
      final container = _containerFor(client);
      addTearDown(container.dispose);

      final attending = await container.read(
        rsvpForceConfirmProvider(
          'new-session',
          'existing-session',
        ).future,
      );

      expect(attending, isTrue);
      expect(client.request?.method, 'POST');
      expect(
        client.request?.path,
        '/api/mobile/protected/spaces/rsvp/new-session/switch',
      );
      final requestBody = client.request?.body;
      if (requestBody is! String) {
        fail('Expected the switch request to contain a JSON string body');
      }
      expect(
        jsonDecode(requestBody),
        <String, dynamic>{'conflicting_session_slug': 'existing-session'},
      );
    });
  });
}
