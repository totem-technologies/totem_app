import 'package:totem_core/core/api/api_client/api_client.dart';

enum AdmissionStatus {
  idle,
  pending,
  approved,
  denied,
  expired,
  cancelled,
  ended,
  failed,
}

enum AdmissionKeeperAvailability { checking, absent, unresponsive, responsive }

extension AdmissionAttemptStatusProperties on ParticipantStatus {
  bool get hasAdmissionDecision =>
      this == ParticipantStatus.granting || isAuthorized;
  bool get isAuthorized =>
      this == ParticipantStatus.approved || this == ParticipantStatus.activated;
}
