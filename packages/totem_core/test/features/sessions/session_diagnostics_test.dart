import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/admission/session_admission_service.dart';
import 'package:totem_core/features/sessions/controllers/core/session_diagnostics.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

void main() {
  SessionDiagnosticSnapshot snapshot({
    SessionTransportConnectionState state =
        SessionTransportConnectionState.connected,
    AdmissionRosterTrust trust = AdmissionRosterTrust.verified,
    List<String> remotes = const [],
    Map<String, String> media = const {},
  }) => SessionDiagnosticSnapshot(
    sessionSlug: 'session',
    correlationId: 'correlation',
    connection: state,
    remoteIdentities: remotes,
    keeperIdentity: 'keeper',
    keeperPresent: true,
    rosterTrust: trust,
    rosterGeneration: 'generation',
    rosterRevision: 1,
    admittedCount: remotes.length,
    localAdmitted: true,
    publicationStates: media,
    blockedSubscriptionReasons: const [],
    admissionRecoveryActive: false,
    mediaRecoveryActive: false,
  );

  test('classifies inconsistent and potentially legitimate session states', () {
    check(
      snapshot().classification,
    ).equals(SessionDiagnosticClassification.alone);
    check(
      snapshot(trust: AdmissionRosterTrust.unverified).classification,
    ).equals(SessionDiagnosticClassification.unverifiedAdmission);
    check(
      snapshot(
        remotes: ['remote'],
        media: {'camera': 'unavailable'},
      ).classification,
    ).equals(SessionDiagnosticClassification.unavailableMedia);
    check(
      snapshot(
        state: SessionTransportConnectionState.reconnecting,
      ).classification,
    ).equals(SessionDiagnosticClassification.reconnecting);
    check(
      snapshot(
        state: SessionTransportConnectionState.disconnected,
      ).classification,
    ).equals(SessionDiagnosticClassification.disconnected);
  });
}
