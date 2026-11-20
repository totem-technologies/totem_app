import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/services/repository_utils.dart';

/// Authenticated Keeper admission operations. Callers own command IDs and
/// payloads so an uncertain outcome can be retried without changing either.
class KeeperAdmissionRepository {
  const KeeperAdmissionRepository({required this.apiService});

  final ClientApi apiService;

  Future<AdmissionSnapshot> snapshot({required String sessionSlug}) =>
      RepositoryUtils.handleApiCall<AdmissionSnapshot>(
        apiCall: () => apiService.rooms.totemRoomsAdmissionApiGetAdmission(
          sessionSlug: sessionSlug,
        ),
        operationName: 'get Keeper admission',
        timeout: const Duration(seconds: 15),
        diagnostics: {'session_slug': sessionSlug},
      );

  Future<AdmissionCommandResponse> approve({
    required String sessionSlug,
    required String identity,
    required KeeperDecisionInput body,
  }) => RepositoryUtils.handleApiCall<AdmissionCommandResponse>(
    apiCall: () => apiService.rooms.totemRoomsAdmissionApiApprove(
      sessionSlug: sessionSlug,
      identity: identity,
      body: body,
    ),
    operationName: 'approve admission',
    timeout: const Duration(seconds: 15),
    diagnostics: {'session_slug': sessionSlug},
  );

  Future<AdmissionCommandResponse> decline({
    required String sessionSlug,
    required String identity,
    required DeclineInput body,
  }) => RepositoryUtils.handleApiCall<AdmissionCommandResponse>(
    apiCall: () => apiService.rooms.totemRoomsAdmissionApiDecline(
      sessionSlug: sessionSlug,
      identity: identity,
      body: body,
    ),
    operationName: 'decline admission',
    timeout: const Duration(seconds: 15),
    diagnostics: {'session_slug': sessionSlug},
  );

  Future<AdmissionCommandResponse> admitAll({
    required String sessionSlug,
    required BatchCommandInput body,
  }) => RepositoryUtils.handleApiCall<AdmissionCommandResponse>(
    apiCall: () => apiService.rooms.totemRoomsAdmissionApiAdmitAll(
      sessionSlug: sessionSlug,
      body: body,
    ),
    operationName: 'admit all',
    timeout: const Duration(seconds: 15),
    diagnostics: {'session_slug': sessionSlug},
  );

  Future<AdmissionCommandResponse> settings({
    required String sessionSlug,
    required SettingsCommandInput body,
  }) => RepositoryUtils.handleApiCall<AdmissionCommandResponse>(
    apiCall: () => apiService.rooms.totemRoomsAdmissionApiUpdateSettings(
      sessionSlug: sessionSlug,
      body: body,
    ),
    operationName: 'update admission settings',
    timeout: const Duration(seconds: 15),
    diagnostics: {'session_slug': sessionSlug},
  );

  Future<AdmissionCommandResponse> allow({
    required String sessionSlug,
    required String identity,
    required MembershipCommandInput body,
  }) => RepositoryUtils.handleApiCall<AdmissionCommandResponse>(
    apiCall: () => apiService.rooms.totemRoomsAdmissionApiAllow(
      sessionSlug: sessionSlug,
      identity: identity,
      body: body,
    ),
    operationName: 'allow admission',
    timeout: const Duration(seconds: 15),
    diagnostics: {'session_slug': sessionSlug},
  );
}
