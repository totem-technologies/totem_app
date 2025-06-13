// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/event_calendar_schema.dart';
import '../models/event_detail_schema.dart';
import '../models/filter_options_schema.dart';
import '../models/paged_event_list_schema.dart';
import '../models/webflow_event_schema.dart';

part 'events_client.g.dart';

@RestApi()
abstract class EventsClient {
  factory EventsClient(Dio dio, {String? baseUrl}) = _EventsClient;

  /// List Events
  @GET('/api/v1/spaces/')
  Future<PagedEventListSchema> totemCirclesApiListEvents({
    @Query('category') required String? category,
    @Query('author') required String? author,
    @Query('limit') int limit = 100,
    @Query('offset') int offset = 0,
  });

  /// Filter Options
  @GET('/api/v1/spaces/filter-options')
  Future<FilterOptionsSchema> totemCirclesApiFilterOptions();

  /// Event Detail
  @GET('/api/v1/spaces/event/{event_slug}')
  Future<EventDetailSchema> totemCirclesApiEventDetail({
    @Path('event_slug') required String eventSlug,
  });

  /// Upcoming Events.
  ///
  /// [spaceSlug] - Space slug.
  ///
  /// [month] - Month of the year, 1-12.
  ///
  /// [year] - Year of the month, e.g. 2024.
  @GET('/api/v1/spaces/calendar')
  Future<List<EventCalendarSchema>> totemCirclesApiUpcomingEvents({
    @Query('space_slug') String spaceSlug = '',
    @Query('month') int month = 6,
    @Query('year') int year = 2025,
  });

  /// Webflow Events List.
  ///
  /// [keeperUsername] - Filter by Keeper's username.
  @GET('/api/v1/spaces/webflow/list_events')
  Future<List<WebflowEventSchema>> totemCirclesApiWebflowEventsList({
    @Query('keeper_username') String? keeperUsername,
  });
}
