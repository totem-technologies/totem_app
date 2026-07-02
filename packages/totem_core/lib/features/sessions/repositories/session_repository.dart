import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/core/services/repository_utils.dart';

part 'session_repository.g.dart';

const _shortTimeoutDuration = Duration(seconds: 10);
const _timeoutDuration = Duration(seconds: 15);

Future<RoomState> _postEvent({
  required ClientApi apiService,
  required String sessionSlug,
  required EventRequestEvent event,
  required int lastSeenVersion,
  required String operationName,
  Duration? timeout,
}) async {
  try {
    return await RepositoryUtils.handleApiCall<RoomState>(
      apiCall: () => apiService.rooms.totemRoomsApiPostEvent(
        sessionSlug: sessionSlug,
        body: EventRequest(
          event: event,
          lastSeenVersion: lastSeenVersion,
        ),
      ),
      operationName: operationName,
      retryOnNetworkError: true,
      timeout: timeout,
    );
  } on ApiError<RoomState, RoomErrorResponse> catch (error) {
    final isStaleVersionError = error.error?.code == ErrorCode.staleVersion;
    if (!isStaleVersionError) {
      rethrow;
    }

    final roomState = await RepositoryUtils.handleApiCall<RoomState>(
      apiCall: () =>
          apiService.rooms.totemRoomsApiGetState(sessionSlug: sessionSlug),
      operationName: 'refresh room state',
      retryOnNetworkError: true,
      timeout: timeout,
    );

    return RepositoryUtils.handleApiCall<RoomState>(
      apiCall: () => apiService.rooms.totemRoomsApiPostEvent(
        sessionSlug: sessionSlug,
        body: EventRequest(
          event: event,
          lastSeenVersion: roomState.version,
        ),
      ),
      operationName: operationName,
      retryOnNetworkError: true,
      timeout: timeout,
    );
  }
}

@riverpod
Future<JoinResponse> sessionToken(Ref ref, String sessionSlug) async {
  final apiService = ref.read(apiServiceProvider);
  try {
    final response = await apiService.rooms
        .totemRoomsApiJoinRoom(sessionSlug: sessionSlug)
        .timeout(_shortTimeoutDuration);
    return response.dataOrThrow;
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
  final apiService = ref.read(apiServiceProvider);
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
  final apiService = ref.read(apiServiceProvider);
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
  final apiService = ref.read(apiServiceProvider);
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

/// Disables the camera of a participant.
///
/// An error can be thrown if the participant camera is already disabled .
@riverpod
Future<void> disableParticipantCamera(
  Ref ref,
  String sessionSlug,
  String participantIdentity,
) async {
  final apiService = ref.read(apiServiceProvider);
  await RepositoryUtils.handleApiCall<void>(
    apiCall: () => apiService.rooms.totemRoomsApiDisableCamera(
      sessionSlug: sessionSlug,
      participantIdentity: participantIdentity,
    ),
    operationName: 'disable camera',
    retryOnNetworkError: true,
  );
}

@riverpod
Future<RoomState> passTotem(
  Ref ref,
  String sessionSlug,
  int lastSeenVersion, {
  String? roundMessage,
}) {
  final apiService = ref.read(apiServiceProvider);
  return _postEvent(
    apiService: apiService,
    sessionSlug: sessionSlug,
    event: EventRequestEventPassStick(PassStickEvent(prompt: roundMessage)),
    lastSeenVersion: lastSeenVersion,
    operationName: 'pass totem',
    timeout: _timeoutDuration,
  );
}

@riverpod
Future<RoomState> acceptTotem(
  Ref ref,
  String sessionSlug,
  int lastSeenVersion,
) {
  final apiService = ref.read(apiServiceProvider);
  return _postEvent(
    apiService: apiService,
    sessionSlug: sessionSlug,
    event: const EventRequestEventAcceptStick(AcceptStickEvent()),
    lastSeenVersion: lastSeenVersion,
    operationName: 'accept totem',
    timeout: _timeoutDuration,
  );
}

@riverpod
Future<RoomState> forcePassTotem(
  Ref ref,
  String sessionSlug,
  int lastSeenVersion,
) {
  final apiService = ref.read(apiServiceProvider);
  return _postEvent(
    apiService: apiService,
    sessionSlug: sessionSlug,
    event: const EventRequestEventForcePassStick(ForcePassStickEvent()),
    lastSeenVersion: lastSeenVersion,
    operationName: 'force pass totem',
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
  final apiService = ref.read(apiServiceProvider);
  return _postEvent(
    apiService: apiService,
    sessionSlug: sessionSlug,
    event: EventRequestEventReorder(ReorderEvent(talkingOrder: order)),
    lastSeenVersion: lastSeenVersion,
    operationName: 'reorder participants',
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
  final apiService = ref.read(apiServiceProvider);
  return _postEvent(
    apiService: apiService,
    sessionSlug: sessionSlug,
    event: const EventRequestEventStartRoom(StartRoomEvent()),
    lastSeenVersion: lastSeenVersion,
    operationName: 'start session',
  );
}

@riverpod
Future<RoomState> endSession(
  Ref ref,
  String sessionSlug,
  int lastSeenVersion,
) {
  final apiService = ref.read(apiServiceProvider);
  return _postEvent(
    apiService: apiService,
    sessionSlug: sessionSlug,
    event: const EventRequestEventEndRoom(
      EndRoomEvent(reason: EndReason.keeperEnded),
    ),
    lastSeenVersion: lastSeenVersion,
    operationName: 'end session',
  );
}

@riverpod
Future<RoomState> banParticipant(
  Ref ref,
  String sessionSlug,
  String participantSlug,
  int lastSeenVersion,
) {
  final apiService = ref.read(apiServiceProvider);
  return _postEvent(
    apiService: apiService,
    sessionSlug: sessionSlug,
    event: EventRequestEventBanParticipant(
      BanParticipantEvent(participantSlug: participantSlug),
    ),
    lastSeenVersion: lastSeenVersion,
    operationName: 'ban participant',
  );
}

@riverpod
Future<RoomState> unbanParticipant(
  Ref ref,
  String sessionSlug,
  String participantSlug,
  int lastSeenVersion,
) {
  final apiService = ref.read(apiServiceProvider);
  return _postEvent(
    apiService: apiService,
    sessionSlug: sessionSlug,
    event: EventRequestEventUnbanParticipant(
      UnbanParticipantEvent(participantSlug: participantSlug),
    ),
    lastSeenVersion: lastSeenVersion,
    operationName: 'unban participant',
  );
}

@riverpod
Future<void> sessionFeedback(
  Ref ref,
  String sessionSlug,
  SessionFeedbackOptions feedback, [
  String? message,
]) {
  final apiService = ref.read(apiServiceProvider);
  return RepositoryUtils.handleApiCall<void>(
    apiCall: () => apiService.spaces.totemSpacesMobileApiPostSessionFeedback(
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
