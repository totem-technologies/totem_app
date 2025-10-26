import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/api/meetings/meetings_client.dart';
import 'package:totem_app/api/mobile_totem_api.dart';
import 'package:totem_app/api/models/livekit_token_response_schema.dart';

class MockMeetingsClient extends Mock implements MeetingsClient {}

class MockMobileTotemApi extends Mock implements MobileTotemApi {}

Future<String> testGetSessionToken(
  MobileTotemApi apiService,
  String eventSlug,
) async {
  final response = await apiService.meetings
      .totemMeetingsMobileApiGetLivekitToken(eventSlug: eventSlug);
  return response.token;
}

void main() {
  group('Session Repository Tests', () {
    late MockMeetingsClient mockMeetingsClient;
    late MockMobileTotemApi mockMobileTotemApi;

    setUpAll(() {
      registerFallbackValue(
        const LivekitTokenResponseSchema(
          token: 'test-token',
        ),
      );
    });

    setUp(() {
      mockMeetingsClient = MockMeetingsClient();
      mockMobileTotemApi = MockMobileTotemApi();

      when(() => mockMobileTotemApi.meetings).thenReturn(mockMeetingsClient);
    });

    group('sessionToken', () {
      test('should return session token successfully', () async {
        const testEventSlug = 'test-event-slug';
        const testTokenResponse = LivekitTokenResponseSchema(
          token: 'test-session-token',
        );

        when(
          () => mockMeetingsClient.totemMeetingsMobileApiGetLivekitToken(
            eventSlug: any(named: 'eventSlug'),
          ),
        ).thenAnswer((_) async => testTokenResponse);

        final result = await testGetSessionToken(
          mockMobileTotemApi,
          testEventSlug,
        );

        expect(result, equals('test-session-token'));
        verify(
          () => mockMeetingsClient.totemMeetingsMobileApiGetLivekitToken(
            eventSlug: testEventSlug,
          ),
        ).called(1);
      });

      test('should handle DioException with 404 status', () async {
        const testEventSlug = 'test-event-slug';
        when(
          () => mockMeetingsClient.totemMeetingsMobileApiGetLivekitToken(
            eventSlug: any(named: 'eventSlug'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/sessions/$testEventSlug'),
            response: Response(
              requestOptions: RequestOptions(path: '/sessions/$testEventSlug'),
              statusCode: 404,
              data: 'Event not found',
            ),
          ),
        );

        expect(
          () => testGetSessionToken(mockMobileTotemApi, testEventSlug),
          throwsA(isA<DioException>()),
        );
        verify(
          () => mockMeetingsClient.totemMeetingsMobileApiGetLivekitToken(
            eventSlug: testEventSlug,
          ),
        ).called(1);
      });

      test('should handle DioException with 401 status', () async {
        const testEventSlug = 'test-event-slug';
        when(
          () => mockMeetingsClient.totemMeetingsMobileApiGetLivekitToken(
            eventSlug: any(named: 'eventSlug'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/sessions/$testEventSlug'),
            response: Response(
              requestOptions: RequestOptions(path: '/sessions/$testEventSlug'),
              statusCode: 401,
              data: 'Unauthorized',
            ),
          ),
        );

        expect(
          () => testGetSessionToken(mockMobileTotemApi, testEventSlug),
          throwsA(isA<DioException>()),
        );
        verify(
          () => mockMeetingsClient.totemMeetingsMobileApiGetLivekitToken(
            eventSlug: testEventSlug,
          ),
        ).called(1);
      });

      test('should handle DioException with 500 status', () async {
        const testEventSlug = 'test-event-slug';
        when(
          () => mockMeetingsClient.totemMeetingsMobileApiGetLivekitToken(
            eventSlug: any(named: 'eventSlug'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/sessions/$testEventSlug'),
            response: Response(
              requestOptions: RequestOptions(path: '/sessions/$testEventSlug'),
              statusCode: 500,
              data: 'Internal Server Error',
            ),
          ),
        );

        expect(
          () => testGetSessionToken(mockMobileTotemApi, testEventSlug),
          throwsA(isA<DioException>()),
        );
        verify(
          () => mockMeetingsClient.totemMeetingsMobileApiGetLivekitToken(
            eventSlug: testEventSlug,
          ),
        ).called(1);
      });

      test('should handle DioException without response', () async {
        const testEventSlug = 'test-event-slug';
        when(
          () => mockMeetingsClient.totemMeetingsMobileApiGetLivekitToken(
            eventSlug: any(named: 'eventSlug'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/sessions/$testEventSlug'),
            type: DioExceptionType.connectionTimeout,
          ),
        );

        expect(
          () => testGetSessionToken(mockMobileTotemApi, testEventSlug),
          throwsA(isA<DioException>()),
        );
        verify(
          () => mockMeetingsClient.totemMeetingsMobileApiGetLivekitToken(
            eventSlug: testEventSlug,
          ),
        ).called(1);
      });

      test('should handle network timeout', () async {
        const testEventSlug = 'test-event-slug';
        when(
          () => mockMeetingsClient.totemMeetingsMobileApiGetLivekitToken(
            eventSlug: any(named: 'eventSlug'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/sessions/$testEventSlug'),
            type: DioExceptionType.receiveTimeout,
            message: 'Connection timeout',
          ),
        );

        expect(
          () => testGetSessionToken(mockMobileTotemApi, testEventSlug),
          throwsA(isA<DioException>()),
        );
        verify(
          () => mockMeetingsClient.totemMeetingsMobileApiGetLivekitToken(
            eventSlug: testEventSlug,
          ),
        ).called(1);
      });

      test('should handle connection error', () async {
        const testEventSlug = 'test-event-slug';
        when(
          () => mockMeetingsClient.totemMeetingsMobileApiGetLivekitToken(
            eventSlug: any(named: 'eventSlug'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/sessions/$testEventSlug'),
            type: DioExceptionType.connectionError,
            message: 'No internet connection',
          ),
        );

        expect(
          () => testGetSessionToken(mockMobileTotemApi, testEventSlug),
          throwsA(isA<DioException>()),
        );
        verify(
          () => mockMeetingsClient.totemMeetingsMobileApiGetLivekitToken(
            eventSlug: testEventSlug,
          ),
        ).called(1);
      });
    });
  });
}
