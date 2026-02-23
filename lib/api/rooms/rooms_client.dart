// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/event_request.dart';
import '../models/join_response.dart';
import '../models/room_state.dart';

part 'rooms_client.g.dart';

@RestApi()
abstract class RoomsClient {
  factory RoomsClient(Dio dio, {String? baseUrl}) = _RoomsClient;

  /// Submit a state transition event.
  ///
  /// All state mutations go through this endpoint. The server validates the transition, persists it, and broadcasts the new state to LiveKit.
  @POST('/api/mobile/protected/rooms/{session_slug}/event')
  Future<RoomState> totemRoomsApiPostEvent({
    @Path('session_slug') required String sessionSlug,
    @Body() required EventRequest body,
  });

  /// Get current room state.
  ///
  /// Returns the current state snapshot. Used by clients on reconnect or as a fallback poll when LiveKit data messages may have been missed.
  @GET('/api/mobile/protected/rooms/{session_slug}/state')
  Future<RoomState> totemRoomsApiGetState({
    @Path('session_slug') required String sessionSlug,
  });

  /// Join a session room.
  ///
  /// Returns a LiveKit access token. Creates the Room if needed.
  @POST('/api/mobile/protected/rooms/{session_slug}/join')
  Future<JoinResponse> totemRoomsApiJoinRoom({
    @Path('session_slug') required String sessionSlug,
  });

  /// Mute a participant.
  ///
  /// Keeper mutes a specific participant's audio.
  @POST(
    '/api/mobile/protected/rooms/{session_slug}/mute/{participant_identity}',
  )
  Future<void> totemRoomsApiMute({
    @Path('session_slug') required String sessionSlug,
    @Path('participant_identity') required String participantIdentity,
  });

  /// Mute all participants.
  ///
  /// Keeper mutes everyone except themselves.
  @POST('/api/mobile/protected/rooms/{session_slug}/mute-all')
  Future<void> totemRoomsApiMuteAll({
    @Path('session_slug') required String sessionSlug,
  });

  /// Remove a participant.
  ///
  /// Keeper removes a participant from the room.
  @POST(
    '/api/mobile/protected/rooms/{session_slug}/remove/{participant_identity}',
  )
  Future<void> totemRoomsApiRemove({
    @Path('session_slug') required String sessionSlug,
    @Path('participant_identity') required String participantIdentity,
  });
}
