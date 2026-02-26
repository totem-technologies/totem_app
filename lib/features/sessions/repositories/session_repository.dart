import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/core/services/repository_utils.dart';

export 'package:totem_app/api/models/session_feedback_schema.dart';

part 'session_repository.g.dart';

const _shortTimeoutDuration = Duration(seconds: 10);
const _timeoutDuration = Duration(seconds: 15);

class SessionErrorResponse extends Error {
  SessionErrorResponse({
    required this.code,
    required this.message,
  });

  factory SessionErrorResponse.fromJson(Map<String, dynamic> json) {
    return SessionErrorResponse(
      code: ErrorCode.values.firstWhere(
        (e) => e.name == json['code'],
        orElse: () => ErrorCode.$unknown,
      ),
      message: json['message'] as String?,
    );
  }

  final ErrorCode code;
  final String? message;
}

@riverpod
Future<String> sessionToken(Ref ref, String sessionSlug) async {
  final apiService = ref.read(mobileApiServiceProvider);
  try {
    final response = await apiService.rooms
        .totemRoomsApiJoinRoom(
          sessionSlug: sessionSlug,
        )
        .timeout(_shortTimeoutDuration);
    return response.token;
  } on DioException catch (error) {
    if (error.response?.statusCode == 403) {
      final json = error.response?.data as Map<String, dynamic>?;
      if (json == null) rethrow;
      throw SessionErrorResponse.fromJson(json);
    }
    rethrow;
  } catch (error) {
    rethrow;
  }
}

@riverpod
Future<void> removeParticipant(
  Ref ref,
  String sessionSlug,
  String participantIdentity,
) {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<void>(
    apiCall: () => apiService.rooms.totemRoomsApiRemove(
      sessionSlug: sessionSlug,
      participantIdentity: participantIdentity,
    ),
    operationName: 'remove participant',
    retryOnNetworkError: true,
  );
}

/// Mutes a participant.
///
/// An error can be thrown if the participant is already muted.
@riverpod
Future<void> muteParticipant(
  Ref ref,
  String sessionSlug,
  String participantIdentity,
) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await RepositoryUtils.handleApiCall<void>(
    apiCall: () => apiService.rooms.totemRoomsApiMute(
      sessionSlug: sessionSlug,
      participantIdentity: participantIdentity,
    ),
    operationName: 'mute participant',
    retryOnNetworkError: true,
  );
}

@riverpod
Future<void> muteEveryone(
  Ref ref,
  String sessionSlug,
) {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<void>(
    apiCall: () =>
        apiService.rooms.totemRoomsApiMuteAll(sessionSlug: sessionSlug),
    operationName: 'mute everyone',
    retryOnNetworkError: true,
  ).timeout(
    _shortTimeoutDuration,
    onTimeout: () => throw AppNetworkException.timeout(),
  );
}

const eventsType = <Type, Object?>{
  EventRequestEventSealedAcceptStickEvent: 'accept_stick',
  EventRequestEventSealedBanParticipantEvent: 'ban_participant',
  EventRequestEventSealedEndRoomEvent: 'end_room',
  EventRequestEventSealedForcePassStickEvent: 'force_pass_stick',
  EventRequestEventSealedPassStickEvent: 'pass_stick',
  EventRequestEventSealedReorderEvent: 'reorder',
  EventRequestEventSealedStartRoomEvent: 'start_room',
  EventRequestEventSealedUnbanParticipantEvent: 'unban_participant',
};

@riverpod
Future<RoomState> passTotem(Ref ref, String sessionSlug, int lastSeenVersion) {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<RoomState>(
    apiCall: () => apiService.rooms.totemRoomsApiPostEvent(
      sessionSlug: sessionSlug,
      body: EventRequest(
        event: EventRequestEventSealedPassStickEvent(
          type: eventsType[EventRequestEventSealedPassStickEvent]! as String,
        ),
        lastSeenVersion: lastSeenVersion,
      ),
    ),
    operationName: 'pass totem',
    retryOnNetworkError: true,
    timeout: _timeoutDuration,
  );
}

@riverpod
Future<RoomState> acceptTotem(
  Ref ref,
  String sessionSlug,
  int lastSeenVersion,
) {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<RoomState>(
    apiCall: () => apiService.rooms.totemRoomsApiPostEvent(
      sessionSlug: sessionSlug,
      body: EventRequest(
        event: EventRequestEventSealedAcceptStickEvent(
          type: eventsType[EventRequestEventSealedAcceptStickEvent]! as String,
        ),
        lastSeenVersion: lastSeenVersion,
      ),
    ),
    operationName: 'accept totem',
    retryOnNetworkError: true,
    timeout: _timeoutDuration,
  );
}

@riverpod
Future<RoomState> forcePassTotem(
  Ref ref,
  String sessionSlug,
  int lastSeenVersion,
) {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<RoomState>(
    apiCall: () => apiService.rooms.totemRoomsApiPostEvent(
      sessionSlug: sessionSlug,
      body: EventRequest(
        event: EventRequestEventSealedForcePassStickEvent(
          type:
              eventsType[EventRequestEventSealedForcePassStickEvent]! as String,
        ),
        lastSeenVersion: lastSeenVersion,
      ),
    ),
    operationName: 'force pass totem',
    retryOnNetworkError: true,
    timeout: _timeoutDuration,
  );
}

@riverpod
Future<RoomState> reorderParticipants(
  Ref ref,
  String sessionSlug,
  List<String> order,
  int lastSeenVersion,
) {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<RoomState>(
    apiCall: () => apiService.rooms.totemRoomsApiPostEvent(
      sessionSlug: sessionSlug,
      body: EventRequest(
        event: EventRequestEventSealedReorderEvent(
          type: eventsType[EventRequestEventSealedReorderEvent]! as String,
          talkingOrder: order,
        ),
        lastSeenVersion: lastSeenVersion,
      ),
    ),
    operationName: 'reorder participants',
    retryOnNetworkError: true,
  ).timeout(
    _shortTimeoutDuration,
    onTimeout: () => throw AppNetworkException.timeout(),
  );
}

@riverpod
Future<RoomState> startSession(
  Ref ref,
  String sessionSlug,
  int lastSeenVersion,
) {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<RoomState>(
    apiCall: () => apiService.rooms.totemRoomsApiPostEvent(
      sessionSlug: sessionSlug,
      body: EventRequest(
        event: EventRequestEventSealedStartRoomEvent(
          type: eventsType[EventRequestEventSealedStartRoomEvent]! as String,
        ),
        lastSeenVersion: lastSeenVersion,
      ),
    ),
    operationName: 'start session',
    retryOnNetworkError: true,
  );
}

@riverpod
Future<RoomState> endSession(
  Ref ref,
  String sessionSlug,
  int lastSeenVersion,
) {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<RoomState>(
    apiCall: () => apiService.rooms.totemRoomsApiPostEvent(
      sessionSlug: sessionSlug,
      body: EventRequest(
        event: EventRequestEventSealedEndRoomEvent(
          type: eventsType[EventRequestEventSealedEndRoomEvent]! as String,
          reason: EndReason.keeperEnded,
        ),
        lastSeenVersion: lastSeenVersion,
      ),
    ),
    operationName: 'end session',
    retryOnNetworkError: true,
  );
}

@riverpod
Future<RoomState> banParticipant(
  Ref ref,
  String sessionSlug,
  String participantSlug,
  int lastSeenVersion,
) {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<RoomState>(
    apiCall: () => apiService.rooms.totemRoomsApiPostEvent(
      sessionSlug: sessionSlug,
      body: EventRequest(
        event: EventRequestEventSealedBanParticipantEvent(
          type:
              eventsType[EventRequestEventSealedBanParticipantEvent]! as String,
          participantSlug: participantSlug,
        ),
        lastSeenVersion: lastSeenVersion,
      ),
    ),
    operationName: 'ban participant',
    retryOnNetworkError: true,
  );
}

@riverpod
Future<RoomState> unbanParticipant(
  Ref ref,
  String sessionSlug,
  String participantSlug,
  int lastSeenVersion,
) {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<RoomState>(
    apiCall: () => apiService.rooms.totemRoomsApiPostEvent(
      sessionSlug: sessionSlug,
      body: EventRequest(
        event: EventRequestEventSealedUnbanParticipantEvent(
          type:
              eventsType[EventRequestEventSealedUnbanParticipantEvent]!
                  as String,
          participantSlug: participantSlug,
        ),
        lastSeenVersion: lastSeenVersion,
      ),
    ),
    operationName: 'unban participant',
    retryOnNetworkError: true,
  );
}

@riverpod
Future<void> sessionFeedback(
  Ref ref,
  String sessionSlug,
  SessionFeedbackOptions feedback, [
  String? message,
]) {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<void>(
    apiCall: () =>
        apiService.spaces.totemSpacesMobileApiMobileApiPostSessionFeedback(
          eventSlug: sessionSlug,
          body: SessionFeedbackSchema(
            feedback: feedback,
            message: message,
          ),
        ),
    operationName: 'end session',
    retryOnNetworkError: true,
  );
}
