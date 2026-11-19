import 'package:totem_core/features/sessions/admission/session_admission_service.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

enum SessionDiagnosticClassification {
  alone,
  unverifiedAdmission,
  unavailableMedia,
  reconnecting,
  disconnected,
  consistent,
}

/// A point-in-time view across the independent session state sources.
class SessionDiagnosticSnapshot {
  const SessionDiagnosticSnapshot({
    required this.sessionSlug,
    required this.correlationId,
    required this.connection,
    required this.remoteIdentities,
    required this.keeperIdentity,
    required this.keeperPresent,
    required this.rosterTrust,
    required this.rosterGeneration,
    required this.rosterRevision,
    required this.admittedCount,
    required this.localAdmitted,
    required this.publicationStates,
    required this.blockedSubscriptionReasons,
    required this.admissionRecoveryActive,
    required this.mediaRecoveryActive,
  });

  final String? sessionSlug;
  final String correlationId;
  final SessionTransportConnectionState connection;
  final List<String> remoteIdentities;
  final String? keeperIdentity;
  final bool keeperPresent;
  final AdmissionRosterTrust rosterTrust;
  final String? rosterGeneration;
  final int? rosterRevision;
  final int admittedCount;
  final bool? localAdmitted;
  final Map<String, String> publicationStates;
  final List<String> blockedSubscriptionReasons;
  final bool admissionRecoveryActive;
  final bool mediaRecoveryActive;

  SessionDiagnosticClassification get classification {
    if (connection == SessionTransportConnectionState.disconnected) {
      return SessionDiagnosticClassification.disconnected;
    }
    if (connection == SessionTransportConnectionState.reconnecting ||
        connection == SessionTransportConnectionState.connecting) {
      return SessionDiagnosticClassification.reconnecting;
    }
    if (rosterTrust != AdmissionRosterTrust.verified) {
      return SessionDiagnosticClassification.unverifiedAdmission;
    }
    if (remoteIdentities.isEmpty) return SessionDiagnosticClassification.alone;
    if (publicationStates.values.any((state) => state != 'subscribed')) {
      return SessionDiagnosticClassification.unavailableMedia;
    }
    return SessionDiagnosticClassification.consistent;
  }
}
