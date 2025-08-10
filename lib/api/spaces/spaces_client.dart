// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';

import '../models/event_detail_schema.dart';
import '../models/paged_space_detail_schema.dart';
import '../models/space_detail_schema.dart';
import '../models/space_schema.dart';
import '../models/summary_spaces_schema.dart';

part 'spaces_client.g.dart';

@RestApi()
abstract class SpacesClient {
  factory SpacesClient(Dio dio, {String? baseUrl}) = _SpacesClient;

  /// Subscribe To Space
  @POST('/api/mobile/protected/spaces/subscribe/{space_slug}')
  Future<bool> totemCirclesMobileApiSubscribeToSpace({
    @Path('space_slug') required String spaceSlug,
  });

  /// Unsubscribe To Space
  @DELETE('/api/mobile/protected/spaces/subscribe/{space_slug}')
  Future<bool> totemCirclesMobileApiUnsubscribeToSpace({
    @Path('space_slug') required String spaceSlug,
  });

  /// List Subscriptions
  @GET('/api/mobile/protected/spaces/subscribe')
  Future<List<SpaceSchema>> totemCirclesMobileApiListSubscriptions();

  /// List Spaces
  @GET('/api/mobile/protected/spaces/')
  Future<PagedSpaceDetailSchema> totemCirclesMobileApiListSpaces({
    @Query('limit') int limit = 100,
    @Query('offset') int offset = 0,
  });

  /// Get Space Detail
  @GET('/api/mobile/protected/spaces/spaces/event/{event_slug}')
  Future<EventDetailSchema> totemCirclesMobileApiGetSpaceDetail({
    @Path('event_slug') required String eventSlug,
  });

  /// Get Keeper Spaces
  @GET('/api/mobile/protected/spaces/keeper/{slug}/')
  Future<List<SpaceDetailSchema>> totemCirclesMobileApiGetKeeperSpaces({
    @Path('slug') required String slug,
  });

  /// Get Sessions History
  @GET('/api/mobile/protected/spaces/sessions/history')
  Future<List<EventDetailSchema>> totemCirclesMobileApiGetSessionsHistory();

  /// Get Recommended Spaces
  @Headers(const {'Content-Type': 'application/json'})
  @GET('/api/mobile/protected/spaces/recommended')
  Future<List<EventDetailSchema>> totemCirclesMobileApiGetRecommendedSpaces({
    @Body() List<String>? body,
    @Query('limit') int limit = 3,
  });

  /// Get Spaces Summary
  @GET('/api/mobile/protected/spaces/summary')
  Future<SummarySpacesSchema> totemCirclesMobileApiGetSpacesSummary();
}
