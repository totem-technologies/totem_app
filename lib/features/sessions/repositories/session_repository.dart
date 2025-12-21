import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/core/services/repository_utils.dart';

export 'package:totem_app/api/models/session_feedback_schema.dart';

part 'session_repository.g.dart';

@riverpod
Future<String> sessionToken(Ref ref, String eventSlug) async {
  final apiService = ref.read(mobileApiServiceProvider);
  return RepositoryUtils.handleApiCall<String>(
    apiCall: () async {
      final response = await apiService.meetings
          .totemMeetingsMobileApiGetLivekitToken(eventSlug: eventSlug);
      return response.token;
    },
    operationName: 'get session token',
    retryOnNetworkError: true,
  );
}

@riverpod
Future<void> removeParticipant(
  Ref ref,
  String eventSlug,
  String participantIdentity,
) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await RepositoryUtils.handleApiCall<void>(
    apiCall: () =>
        apiService.meetings.totemMeetingsMobileApiRemoveParticipantEndpoint(
          eventSlug: eventSlug,
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
  String eventSlug,
  String participantIdentity,
) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await RepositoryUtils.handleApiCall<void>(
    apiCall: () =>
        apiService.meetings.totemMeetingsMobileApiMuteParticipantEndpoint(
          eventSlug: eventSlug,
          participantIdentity: participantIdentity,
        ),
    operationName: 'mute participant',
    retryOnNetworkError: true,
  );
}

@riverpod
Future<void> muteEveryone(
  Ref ref,
  String eventSlug,
) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await RepositoryUtils.handleApiCall<void>(
    apiCall: () =>
        apiService.meetings.totemMeetingsMobileApiMuteAllParticipantsEndpoint(
          eventSlug: eventSlug,
        ),
    operationName: 'mute participant',
    retryOnNetworkError: true,
  );
}

@riverpod
Future<void> passTotem(Ref ref, String eventSlug) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await RepositoryUtils.handleApiCall<void>(
    apiCall: () => apiService.meetings.totemMeetingsMobileApiPassTotemEndpoint(
      eventSlug: eventSlug,
    ),
    operationName: 'pass totem',
    retryOnNetworkError: true,
  );
}

@riverpod
Future<void> reorderParticipants(
  Ref ref,
  String eventSlug,
  List<String> order,
) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await RepositoryUtils.handleApiCall<void>(
    apiCall: () =>
        apiService.meetings.totemMeetingsMobileApiReorderParticipantsEndpoint(
          eventSlug: eventSlug,
          body: LivekitMuteParticipantSchema(order: order),
        ),
    operationName: 'reorder participants',
    retryOnNetworkError: true,
  );
}

@riverpod
Future<void> startSession(Ref ref, String eventSlug) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await RepositoryUtils.handleApiCall<void>(
    apiCall: () => apiService.meetings.totemMeetingsMobileApiStartRoomEndpoint(
      eventSlug: eventSlug,
    ),
    operationName: 'start session',
    retryOnNetworkError: true,
  );
}

@riverpod
Future<void> endSession(Ref ref, String eventSlug) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await RepositoryUtils.handleApiCall<void>(
    apiCall: () => apiService.meetings.totemMeetingsMobileApiEndRoomEndpoint(
      eventSlug: eventSlug,
    ),
    operationName: 'end session',
    retryOnNetworkError: true,
  );
}

@riverpod
Future<void> sessionFeedback(
  Ref ref,
  String eventSlug,
  SessionFeedbackOptions feedback, [
  String? message,
]) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await RepositoryUtils.handleApiCall<void>(
    apiCall: () =>
        apiService.spaces.totemCirclesMobileApiMobileApiPostSessionFeedback(
          eventSlug: eventSlug,
          body: SessionFeedbackSchema(
            feedback: feedback,
            message: message,
          ),
        ),
    operationName: 'end session',
    retryOnNetworkError: true,
  );
}
