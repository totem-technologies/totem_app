import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';

void main() {
  group('isInternetDisconnectReason', () {
    test('recognizes explicit client-side network failures', () {
      expect(
        isInternetDisconnectReason(DisconnectReason.signalingConnectionFailure),
        isTrue,
      );
      expect(
        isInternetDisconnectReason(DisconnectReason.reconnectAttemptsExceeded),
        isTrue,
      );
    });

    test('does not infer internet loss from a closed signaling connection', () {
      expect(
        isInternetDisconnectReason(DisconnectReason.disconnected),
        isFalse,
      );
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
        expect(
          canOfflineStateOverrideDisconnectReason(reason),
          isTrue,
          reason: '$reason should allow a confirmed offline override',
        );
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
        expect(
          canOfflineStateOverrideDisconnectReason(reason),
          isFalse,
          reason: '$reason should keep its explicit disconnect messaging',
        );
      }
    });
  });
}
