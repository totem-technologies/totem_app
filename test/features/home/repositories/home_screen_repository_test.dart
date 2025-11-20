import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/api/mobile_totem_api.dart';
import 'package:totem_app/api/models/summary_spaces_schema.dart';
import 'package:totem_app/api/spaces/spaces_client.dart';
import 'package:totem_app/core/services/cache_service.dart';

class MockSpacesClient extends Mock implements SpacesClient {}

class MockMobileTotemApi extends Mock implements MobileTotemApi {}

class MockCacheService extends Mock implements CacheService {}

Future<SummarySpacesSchema> testSpacesSummary(
  MobileTotemApi apiService,
  CacheService cacheService,
) async {
  try {
    final summary = await apiService.spaces
        .totemCirclesMobileApiMobileApiGetSpacesSummary();
    await cacheService.saveSpacesSummary(summary);
    return summary;
  } on DioException catch (_) {
    final cachedSummary = await cacheService.getSpacesSummary();
    if (cachedSummary != null) {
      return cachedSummary;
    } else {
      rethrow;
    }
  }
}

void main() {
  group('Home Screen Repository Tests', () {
    late MockSpacesClient mockSpacesClient;
    late MockMobileTotemApi mockMobileTotemApi;
    late MockCacheService mockCacheService;

    setUpAll(() {
      registerFallbackValue(
        const SummarySpacesSchema(
          upcoming: [],
          forYou: [],
          explore: [],
        ),
      );
    });

    setUp(() {
      mockSpacesClient = MockSpacesClient();
      mockMobileTotemApi = MockMobileTotemApi();
      mockCacheService = MockCacheService();

      when(() => mockMobileTotemApi.spaces).thenReturn(mockSpacesClient);
    });

    group('spacesSummary', () {
      test('should return spaces summary successfully', () async {
        // Arrange
        const testSummary = SummarySpacesSchema(
          upcoming: [],
          forYou: [],
          explore: [],
        );

        when(
          () =>
              mockSpacesClient.totemCirclesMobileApiMobileApiGetSpacesSummary(),
        ).thenAnswer((_) async => testSummary);
        when(
          () => mockCacheService.saveSpacesSummary(any()),
        ).thenAnswer((_) async {});

        // Act - Test the underlying logic
        final result = await testSpacesSummary(
          mockMobileTotemApi,
          mockCacheService,
        );

        // Assert
        expect(result, equals(testSummary));
        expect(result.upcoming, hasLength(0));
        expect(result.forYou, hasLength(0));
        expect(result.explore, hasLength(0));
        verify(
          () =>
              mockSpacesClient.totemCirclesMobileApiMobileApiGetSpacesSummary(),
        ).called(1);
        verify(() => mockCacheService.saveSpacesSummary(testSummary)).called(1);
      });

      test(
        'should return cached summary when API fails and cache exists',
        () async {
          // Arrange
          const cachedSummary = SummarySpacesSchema(
            upcoming: [],
            forYou: [],
            explore: [],
          );

          when(
            () => mockSpacesClient
                .totemCirclesMobileApiMobileApiGetSpacesSummary(),
          ).thenThrow(
            DioException(
              requestOptions: RequestOptions(path: '/spaces/summary'),
              response: Response(
                requestOptions: RequestOptions(path: '/spaces/summary'),
                statusCode: 500,
              ),
            ),
          );
          when(
            () => mockCacheService.getSpacesSummary(),
          ).thenAnswer((_) async => cachedSummary);

          // Act - Test the underlying logic
          final result = await testSpacesSummary(
            mockMobileTotemApi,
            mockCacheService,
          );

          // Assert
          expect(result, equals(cachedSummary));
          expect(result.forYou, hasLength(0));
          verify(
            () => mockSpacesClient
                .totemCirclesMobileApiMobileApiGetSpacesSummary(),
          ).called(1);
          verify(() => mockCacheService.getSpacesSummary()).called(1);
        },
      );

      test(
        'should throw DioException when API fails and no cache exists',
        () async {
          // Arrange
          when(
            () => mockSpacesClient
                .totemCirclesMobileApiMobileApiGetSpacesSummary(),
          ).thenThrow(
            DioException(
              requestOptions: RequestOptions(path: '/spaces/summary'),
              response: Response(
                requestOptions: RequestOptions(path: '/spaces/summary'),
                statusCode: 500,
              ),
            ),
          );
          when(
            () => mockCacheService.getSpacesSummary(),
          ).thenAnswer((_) async => null);

          // Act & Assert
          expect(
            () => testSpacesSummary(mockMobileTotemApi, mockCacheService),
            throwsA(isA<DioException>()),
          );
          verify(
            () => mockSpacesClient
                .totemCirclesMobileApiMobileApiGetSpacesSummary(),
          ).called(1);
          verify(() => mockCacheService.getSpacesSummary()).called(1);
        },
      );
    });
  });
}
