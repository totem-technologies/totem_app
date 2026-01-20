// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/mobile_space_detail_schema.dart';
import '../models/paged_mobile_space_detail_schema.dart';
import '../models/session_detail_schema.dart';
import '../models/session_feedback_schema.dart';
import '../models/space_schema.dart';
import '../models/summary_spaces_schema.dart';

part 'spaces_client.g.dart';

@RestApi()
abstract class SpacesClient {
  factory SpacesClient(Dio dio, {String? baseUrl}) = _SpacesClient;

  /// Subscribe To Space
  @POST('/api/mobile/protected/spaces/subscribe/{space_slug}')
  Future<bool> totemSpacesMobileApiMobileApiSubscribeToSpace({
    @Path('space_slug') required String spaceSlug,
  });

  /// Unsubscribe To Space
  @DELETE('/api/mobile/protected/spaces/subscribe/{space_slug}')
  Future<bool> totemSpacesMobileApiMobileApiUnsubscribeToSpace({
    @Path('space_slug') required String spaceSlug,
  });

  /// List Subscriptions
  @GET('/api/mobile/protected/spaces/subscribe')
  Future<List<SpaceSchema>> totemSpacesMobileApiMobileApiListSubscriptions();

  /// List Spaces
  @GET('/api/mobile/protected/spaces/')
  Future<PagedMobileSpaceDetailSchema> totemSpacesMobileApiMobileApiListSpaces({
    @Query('limit') int? limit = 100,
    @Query('offset') int? offset = 0,
  });

  /// Get Space Detail
  @GET('/api/mobile/protected/spaces/space/{space_slug}')
  Future<MobileSpaceDetailSchema> totemSpacesMobileApiMobileApiGetSpaceDetail({
    @Path('space_slug') required String spaceSlug,
  });

  /// Get Keeper Spaces
  @GET('/api/mobile/protected/spaces/keeper/{slug}/')
  Future<List<MobileSpaceDetailSchema>>
  totemSpacesMobileApiMobileApiGetKeeperSpaces({
    @Path('slug') required String slug,
  });

  /// Get Session Detail
  @GET('/api/mobile/protected/spaces/session/{event_slug}')
  Future<SessionDetailSchema> totemSpacesMobileApiMobileApiGetSessionDetail({
    @Path('event_slug') required String eventSlug,
  });

  /// Post Session Feedback
  @POST('/api/mobile/protected/spaces/session/{event_slug}/feedback')
  Future<void> totemSpacesMobileApiMobileApiPostSessionFeedback({
    @Path('event_slug') required String eventSlug,
    @Body() required SessionFeedbackSchema body,
  });

  /// Get Sessions History
  @GET('/api/mobile/protected/spaces/sessions/history')
  Future<List<SessionDetailSchema>>
  totemSpacesMobileApiMobileApiGetSessionsHistory();

  /// Get Recommended Spaces
  @GET('/api/mobile/protected/spaces/sessions/recommended')
  Future<List<SessionDetailSchema>>
  totemSpacesMobileApiMobileApiGetRecommendedSpaces({
    @Body() List<String>? body,
    @Query('limit') int? limit = 3,
  });

  /// Get Spaces Summary
  @GET('/api/mobile/protected/spaces/summary')
  Future<SummarySpacesSchema> totemSpacesMobileApiMobileApiGetSpacesSummary();

  /// Rsvp Confirm
  @POST('/api/mobile/protected/spaces/rsvp/{event_slug}')
  Future<SessionDetailSchema> totemSpacesMobileApiMobileApiRsvpConfirm({
    @Path('event_slug') required String eventSlug,
  });

  /// Rsvp Cancel
  @DELETE('/api/mobile/protected/spaces/rsvp/{event_slug}')
  Future<SessionDetailSchema> totemSpacesMobileApiMobileApiRsvpCancel({
    @Path('event_slug') required String eventSlug,
  });
}
