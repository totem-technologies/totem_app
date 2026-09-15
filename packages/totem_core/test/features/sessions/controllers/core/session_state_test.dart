import 'package:flutter_test/flutter_test.dart';
import 'package:checks/checks.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';

void main() {
  group('isInternetDisconnectReason', () {
    test('recognizes explicit client-side network failures', () {
      check(
        isInternetDisconnectReason(DisconnectReason.signalingConnectionFailure),
      ).equals(true);
      check(
        isInternetDisconnectReason(DisconnectReason.reconnectAttemptsExceeded),
      ).equals(true);
    });

    test('does not infer internet loss from a closed signaling connection', () {
      check(
        isInternetDisconnectReason(DisconnectReason.disconnected),
      ).equals(false);
    });
  });

  group('canOfflineStateOverrideDisconnectReason', () {
    test('allows ambiguous client-side reasons', () {
      for (final reason in <DisconnectReason?>[
        null,
        DisconnectReason.unknown,
        DisconnectReason.joinFailure,
        DisconnectReason.disconnected,
        DisconnectReason.signalingConnectionFailure,
        DisconnectReason.reconnectAttemptsExceeded,
        DisconnectReason.signalClose,
        DisconnectReason.mediaFailure,
      ]) {
        check(
          because: '$reason should allow a confirmed offline override',
          canOfflineStateOverrideDisconnectReason(reason),
        ).equals(true);
      }
    });

    test('preserves explicit server-side and user-initiated reasons', () {
      for (final reason in [
        DisconnectReason.clientInitiated,
        DisconnectReason.duplicateIdentity,
        DisconnectReason.serverShutdown,
        DisconnectReason.participantRemoved,
        DisconnectReason.roomDeleted,
        DisconnectReason.stateMismatch,
        DisconnectReason.migration,
        DisconnectReason.roomClosed,
        DisconnectReason.userUnavailable,
        DisconnectReason.userRejected,
        DisconnectReason.sipTrunkFailure,
        DisconnectReason.connectionTimeout,
        DisconnectReason.agentError,
      ]) {
        check(
          because: '$reason should keep its explicit disconnect messaging',
          canOfflineStateOverrideDisconnectReason(reason),
        ).equals(false);
      }
    });
  });
}
