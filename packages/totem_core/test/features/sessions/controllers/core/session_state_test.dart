import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';

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

  group('session outcome vs technical disconnects', () {
    const outcomes = {
      DisconnectReason.clientInitiated,
      DisconnectReason.duplicateIdentity,
      DisconnectReason.participantRemoved,
      DisconnectReason.roomDeleted,
      DisconnectReason.roomClosed,
    };

    test('only real session outcomes keep the session-ended treatment', () {
      for (final reason in DisconnectReason.values) {
        check(
          because: '$reason',
          isSessionOutcomeDisconnectReason(reason),
        ).equals(outcomes.contains(reason));
        check(
          because: '$reason',
          isTechnicalDisconnectReason(reason),
        ).equals(!outcomes.contains(reason));
      }
    });

    test('an unknown reason is neither', () {
      check(isSessionOutcomeDisconnectReason(null)).isFalse();
      check(isTechnicalDisconnectReason(null)).isFalse();
    });
  });

  group('classifySessionError', () {
    test('maps LiveKit and session failures to what the user can do', () {
      final cases = <(Object?, SessionErrorCategory)>[
        (null, SessionErrorCategory.unknown),
        (StateError('boom'), SessionErrorCategory.unknown),
        (
          ConnectException('denied', reason: ConnectionErrorReason.NotAllowed),
          SessionErrorCategory.accessDenied,
        ),
        (
          ConnectException('slow', reason: ConnectionErrorReason.Timeout),
          SessionErrorCategory.serverUnreachable,
        ),
        (
          ConnectException('500', reason: ConnectionErrorReason.InternalError),
          SessionErrorCategory.serverUnreachable,
        ),
        (MediaConnectException(), SessionErrorCategory.serverUnreachable),
        (TrackCreateException(), SessionErrorCategory.mediaDevice),
        (
          Exception('getUserMedia(): DOMException, NotReadableError'),
          SessionErrorCategory.mediaDevice,
        ),
        (NegotiationError(), SessionErrorCategory.connectionLost),
        (
          MediaPublishException(TrackPublishException()),
          SessionErrorCategory.connectionLost,
        ),
        (
          RoomLiveKitError(MediaConnectException()),
          SessionErrorCategory.serverUnreachable,
        ),
        (
          const RoomDisconnectionError(DisconnectReason.mediaFailure),
          SessionErrorCategory.connectionLost,
        ),
        // LiveKit gives up the same way when only its server is unreachable,
        // so these only read as offline when connectivity agrees.
        (
          const RoomDisconnectionError(
            DisconnectReason.reconnectAttemptsExceeded,
          ),
          SessionErrorCategory.connectionLost,
        ),
        (
          const RoomDisconnectionError(
            DisconnectReason.signalingConnectionFailure,
          ),
          SessionErrorCategory.connectionLost,
        ),
        // On web, LiveKit's validate request fails like this when its server
        // can't be reached.
        (
          ClientException('Failed to fetch'),
          SessionErrorCategory.serverUnreachable,
        ),
        (
          SessionJoinFailure(ClientException('Failed to fetch')),
          SessionErrorCategory.serverUnreachable,
        ),
        (
          SessionJoinFailure(TrackCreateException()),
          SessionErrorCategory.mediaDevice,
        ),
        (const SessionJoinFailure(), SessionErrorCategory.unknown),
      ];
      for (final (error, kind) in cases) {
        check(because: '$error', classifySessionError(error)).equals(kind);
      }
    });

    test('a confirmed offline device explains network failures', () {
      check(
        classifySessionError(MediaConnectException(), isOffline: true),
      ).equals(SessionErrorCategory.offline);
      check(
        classifySessionError(
          const RoomDisconnectionError(DisconnectReason.signalClose),
          isOffline: true,
        ),
      ).equals(SessionErrorCategory.offline);
      check(
        classifySessionError(null, isOffline: true),
      ).equals(SessionErrorCategory.offline);
      for (final reason in [
        DisconnectReason.reconnectAttemptsExceeded,
        DisconnectReason.signalingConnectionFailure,
      ]) {
        check(
          because: '$reason',
          classifySessionError(RoomDisconnectionError(reason), isOffline: true),
        ).equals(SessionErrorCategory.offline);
      }
    });

    test('being offline does not hide a device or access problem', () {
      check(
        classifySessionError(TrackCreateException(), isOffline: true),
      ).equals(SessionErrorCategory.mediaDevice);
      check(
        classifySessionError(
          ConnectException('denied', reason: ConnectionErrorReason.NotAllowed),
          isOffline: true,
        ),
      ).equals(SessionErrorCategory.accessDenied);
    });
  });
}
