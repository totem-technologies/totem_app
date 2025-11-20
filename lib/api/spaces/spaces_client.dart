// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/event_detail_schema.dart';
import '../models/mobile_space_detail_schema.dart';
import '../models/paged_mobile_space_detail_schema.dart';
import '../models/space_schema.dart';
import '../models/summary_spaces_schema.dart';

part 'spaces_client.g.dart';

@RestApi()
abstract class SpacesClient {
  factory SpacesClient(Dio dio, {String? baseUrl}) = _SpacesClient;

  /// Subscribe To Space
  @POST('/api/mobile/protected/spaces/subscribe/{space_slug}')
  Future<bool> totemCirclesMobileApiMobileApiSubscribeToSpace({
    @Path('space_slug') required String spaceSlug,
  });

  /// Unsubscribe To Space
  @DELETE('/api/mobile/protected/spaces/subscribe/{space_slug}')
  Future<bool> totemCirclesMobileApiMobileApiUnsubscribeToSpace({
    @Path('space_slug') required String spaceSlug,
  });

  /// List Subscriptions
  @GET('/api/mobile/protected/spaces/subscribe')
  Future<List<SpaceSchema>> totemCirclesMobileApiMobileApiListSubscriptions();

  /// List Spaces
  @GET('/api/mobile/protected/spaces/')
  Future<PagedMobileSpaceDetailSchema>
  totemCirclesMobileApiMobileApiListSpaces({
    @Query('limit') int? limit = 100,
    @Query('offset') int? offset = 0,
  });

  /// Get Event Detail
  @GET('/api/mobile/protected/spaces/event/{event_slug}')
  Future<EventDetailSchema> totemCirclesMobileApiMobileApiGetEventDetail({
    @Path('event_slug') required String eventSlug,
  });

  /// Get Space Detail
  @GET('/api/mobile/protected/spaces/space/{space_slug}')
  Future<MobileSpaceDetailSchema> totemCirclesMobileApiMobileApiGetSpaceDetail({
    @Path('space_slug') required String spaceSlug,
  });

  /// Get Keeper Spaces
  @GET('/api/mobile/protected/spaces/keeper/{slug}/')
  Future<List<MobileSpaceDetailSchema>>
  totemCirclesMobileApiMobileApiGetKeeperSpaces({
    @Path('slug') required String slug,
  });

  /// Get Sessions History
  @GET('/api/mobile/protected/spaces/sessions/history')
  Future<List<EventDetailSchema>>
  totemCirclesMobileApiMobileApiGetSessionsHistory();

  /// Get Recommended Spaces
  @GET('/api/mobile/protected/spaces/recommended')
  Future<List<EventDetailSchema>>
  totemCirclesMobileApiMobileApiGetRecommendedSpaces({
    @Body() List<String>? body,
    @Query('limit') int? limit = 3,
  });

  /// Get Spaces Summary
  @GET('/api/mobile/protected/spaces/summary')
  Future<SummarySpacesSchema> totemCirclesMobileApiMobileApiGetSpacesSummary();

  /// Rsvp Confirm
  @POST('/api/mobile/protected/spaces/rsvp/{event_slug}')
  Future<EventDetailSchema> totemCirclesMobileApiMobileApiRsvpConfirm({
    @Path('event_slug') required String eventSlug,
  });

  /// Rsvp Cancel
  @DELETE('/api/mobile/protected/spaces/rsvp/{event_slug}')
  Future<EventDetailSchema> totemCirclesMobileApiMobileApiRsvpCancel({
    @Path('event_slug') required String eventSlug,
  });
}
