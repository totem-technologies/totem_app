// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/livekit_mute_participant_schema.dart';
import '../models/livekit_token_response_schema.dart';
import '../models/session_state.dart';

part 'meetings_client.g.dart';

@RestApi()
abstract class MeetingsClient {
  factory MeetingsClient(Dio dio, {String? baseUrl}) = _MeetingsClient;

  /// Get Livekit Token
  @GET('/api/mobile/protected/meetings/event/{event_slug}/token')
  Future<LivekitTokenResponseSchema> totemMeetingsMobileApiGetLivekitToken({
    @Path('event_slug') required String eventSlug,
  });

  /// Pass Totem Endpoint
  @POST('/api/mobile/protected/meetings/event/{event_slug}/pass-totem')
  Future<void> totemMeetingsMobileApiPassTotemEndpoint({
    @Path('event_slug') required String eventSlug,
  });

  /// Accept Totem Endpoint
  @POST('/api/mobile/protected/meetings/event/{event_slug}/accept-totem')
  Future<void> totemMeetingsMobileApiAcceptTotemEndpoint({
    @Path('event_slug') required String eventSlug,
  });

  /// Start Room Endpoint
  @POST('/api/mobile/protected/meetings/event/{event_slug}/start')
  Future<void> totemMeetingsMobileApiStartRoomEndpoint({
    @Path('event_slug') required String eventSlug,
  });

  /// End Room Endpoint
  @POST('/api/mobile/protected/meetings/event/{event_slug}/end')
  Future<void> totemMeetingsMobileApiEndRoomEndpoint({
    @Path('event_slug') required String eventSlug,
  });

  /// Mute Participant Endpoint
  @POST(
    '/api/mobile/protected/meetings/event/{event_slug}/mute/{participant_identity}',
  )
  Future<void> totemMeetingsMobileApiMuteParticipantEndpoint({
    @Path('event_slug') required String eventSlug,
    @Path('participant_identity') required String participantIdentity,
  });

  /// Mute All Participants Endpoint
  @POST('/api/mobile/protected/meetings/event/{event_slug}/mute-all')
  Future<void> totemMeetingsMobileApiMuteAllParticipantsEndpoint({
    @Path('event_slug') required String eventSlug,
  });

  /// Remove Participant Endpoint
  @POST(
    '/api/mobile/protected/meetings/event/{event_slug}/remove/{participant_identity}',
  )
  Future<void> totemMeetingsMobileApiRemoveParticipantEndpoint({
    @Path('event_slug') required String eventSlug,
    @Path('participant_identity') required String participantIdentity,
  });

  /// Reorder Participants Endpoint
  @POST('/api/mobile/protected/meetings/event/{event_slug}/reorder')
  Future<LivekitMuteParticipantSchema>
  totemMeetingsMobileApiReorderParticipantsEndpoint({
    @Path('event_slug') required String eventSlug,
    @Body() required LivekitMuteParticipantSchema body,
  });

  /// Get Room State Endpoint.
  ///
  /// Retrieves the current session state for a room.
  ///
  /// This endpoint exposes the SessionState schema and its enums (SessionStatus, TotemStatus).
  /// in the OpenAPI documentation for client-side usage.
  @GET('/api/mobile/protected/meetings/event/{event_slug}/room-state')
  Future<SessionState> totemMeetingsMobileApiGetRoomStateEndpoint({
    @Path('event_slug') required String eventSlug,
  });
}
