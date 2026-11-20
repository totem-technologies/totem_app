import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/core/services/repository_utils.dart';

part 'participant_admission_repository.g.dart';

@riverpod
ParticipantAdmissionRepository participantAdmissionRepository(Ref ref) =>
    ParticipantAdmissionRepository(apiService: ref.watch(apiServiceProvider));

class ParticipantAdmissionRepository {
  const ParticipantAdmissionRepository({required this.apiService});

  final ClientApi apiService;

  Future<AdmissionMeSnapshot> me({required String sessionSlug}) {
    return RepositoryUtils.handleApiCall<AdmissionMeSnapshot>(
      apiCall: () => apiService.rooms.totemRoomsAdmissionApiGetMyAdmission(
        sessionSlug: sessionSlug,
      ),
      operationName: 'get my admission',
      timeout: const Duration(seconds: 15),
      diagnostics: {'session_slug': sessionSlug},
    );
  }

  Future<AdmissionMeSnapshot> request({
    required String sessionSlug,
    required String requestId,
    required String attemptId,
    bool connected = false,
  }) {
    return RepositoryUtils.handleApiCall<AdmissionMeSnapshot>(
      apiCall: () => apiService.rooms.totemRoomsAdmissionApiRequestAdmission(
        sessionSlug: sessionSlug,
        body: AdmissionRequestInput(
          requestId: requestId,
          attemptId: attemptId,
          connected: connected,
        ),
      ),
      operationName: 'request admission',
      timeout: const Duration(seconds: 15),
      diagnostics: {'session_slug': sessionSlug},
    );
  }

  Future<AdmissionMeSnapshot> activated({
    required String sessionSlug,
    required AttemptReceiptInput receipt,
  }) {
    return RepositoryUtils.handleApiCall<AdmissionMeSnapshot>(
      apiCall: () => apiService.rooms.totemRoomsAdmissionApiActivateAdmission(
        sessionSlug: sessionSlug,
        body: receipt,
      ),
      operationName: 'activate admission',
      timeout: const Duration(seconds: 15),
      diagnostics: {'session_slug': sessionSlug},
    );
  }

  Future<AdmissionMeSnapshot> cancel({
    required String sessionSlug,
    required AttemptReceiptInput receipt,
  }) {
    return RepositoryUtils.handleApiCall<AdmissionMeSnapshot>(
      apiCall: () => apiService.rooms.totemRoomsAdmissionApiCancelAdmission(
        sessionSlug: sessionSlug,
        body: receipt,
      ),
      operationName: 'cancel admission',
      timeout: const Duration(seconds: 15),
      diagnostics: {'session_slug': sessionSlug},
    );
  }
}
