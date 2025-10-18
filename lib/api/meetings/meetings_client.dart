// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/livekit_token_response_schema.dart';

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

  /// Start Room Endpoint
  @POST('/api/mobile/protected/meetings/event/{event_slug}/start')
  Future<void> totemMeetingsMobileApiStartRoomEndpoint({
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
}
