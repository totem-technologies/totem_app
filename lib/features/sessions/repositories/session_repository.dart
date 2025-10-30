import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/models/livekit_mute_participant_schema.dart';
import 'package:totem_app/core/services/api_service.dart';

part 'session_repository.g.dart';

@riverpod
Future<String> sessionToken(Ref ref, String eventSlug) async {
  final apiService = ref.read(mobileApiServiceProvider);
  final response = await apiService.meetings
      .totemMeetingsMobileApiGetLivekitToken(eventSlug: eventSlug);
  return response.token;
}

@riverpod
Future<void> removeParticipant(
  Ref ref,
  String eventSlug,
  String participantIdentity,
) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await apiService.meetings.totemMeetingsMobileApiRemoveParticipantEndpoint(
    eventSlug: eventSlug,
    participantIdentity: participantIdentity,
  );
}

@riverpod
Future<void> muteParticipant(
  Ref ref,
  String eventSlug,
  String participantIdentity,
) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await apiService.meetings.totemMeetingsMobileApiMuteParticipantEndpoint(
    eventSlug: eventSlug,
    participantIdentity: participantIdentity,
  );
}

@riverpod
Future<void> passTotem(Ref ref, String eventSlug) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await apiService.meetings.totemMeetingsMobileApiPassTotemEndpoint(
    eventSlug: eventSlug,
  );
}

@riverpod
Future<void> reorderParticipants(
  Ref ref,
  String eventSlug,
  List<String> order,
) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await apiService.meetings.totemMeetingsMobileApiReorderParticipantsEndpoint(
    eventSlug: eventSlug,
    body: LivekitMuteParticipantSchema(order: order),
  );
}

@riverpod
Future<void> startSession(Ref ref, String eventSlug) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await apiService.meetings.totemMeetingsMobileApiStartRoomEndpoint(
    eventSlug: eventSlug,
  );
}

@riverpod
Future<void> endSession(Ref ref, String eventSlug) async {
  final apiService = ref.read(mobileApiServiceProvider);
  await apiService.meetings.totemMeetingsMobileApiEndRoomEndpoint(
    eventSlug: eventSlug,
  );
}
