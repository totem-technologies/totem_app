import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/core/services/repository_utils.dart';

export 'package:totem_app/api/models/session_feedback_schema.dart';

part 'session_repository.g.dart';

const _shortTimeoutDuration = Duration(seconds: 10);
const _timeoutDuration = Duration(seconds: 15);

@riverpod
Future<String> sessionToken(Ref ref, String sessionSlug) async {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<String>(
    apiCall: () async {
      final response = await apiService.rooms.totemRoomsApiJoinRoom(
        sessionSlug: sessionSlug,
      );
      return response.token;
    },
    operationName: 'get session token',
    retryOnNetworkError: true,
  );
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
    operationName: 'mute participant',
    retryOnNetworkError: true,
  ).timeout(
    _shortTimeoutDuration,
    onTimeout: () => throw AppNetworkException.timeout(),
  );
}

const eventsType = <Type, Object?>{
  EventRequestEventSealedAcceptStickEvent: 'accept_stick',
  EventRequestEventSealedEndRoomEvent: 'end_room',
  EventRequestEventSealedPassStickEvent: 'pass_stick',
  EventRequestEventSealedReorderEvent: 'reorder',
  EventRequestEventSealedStartRoomEvent: 'start_room',
};

@riverpod
Future<void> passTotem(Ref ref, String sessionSlug, int lastSeenVersion) {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<void>(
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
  ).timeout(
    _timeoutDuration,
    onTimeout: () => throw AppNetworkException.timeout(),
  );
}

@riverpod
Future<void> acceptTotem(Ref ref, String sessionSlug, int lastSeenVersion) {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<void>(
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
  ).timeout(
    _timeoutDuration,
    onTimeout: () => throw AppNetworkException.timeout(),
  );
}

@riverpod
Future<void> reorderParticipants(
  Ref ref,
  String sessionSlug,
  List<String> order,
  int lastSeenVersion,
) {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<void>(
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
Future<void> startSession(Ref ref, String sessionSlug, int lastSeenVersion) {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<void>(
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
Future<void> endSession(
  Ref ref,
  String sessionSlug,
  int lastSeenVersion,
) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await RepositoryUtils.handleApiCall<void>(
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
