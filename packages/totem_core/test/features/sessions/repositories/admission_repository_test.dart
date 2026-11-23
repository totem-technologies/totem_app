import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:degenerate_runtime/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/repositories/keeper_admission_repository.dart';
import 'package:totem_core/features/sessions/repositories/participant_admission_repository.dart';

Map<String, Object?> snapshot() => {
  'session_slug': 'session',
  'keeper': 'keeper',
  'room_version': 1,
  'room_state': {
    'session_slug': 'session',
    'version': 1,
    'status': 'waiting_room',
    'turn_state': 'idle',
    'status_detail': {'type': 'waiting_room'},
    'talking_order': <String>[],
    'keeper': 'keeper',
    'round_number': 1,
  },
  'room_status': 'active',
  'approval_required': true,
  'settings_revision': 1,
  'version': 2,
  'observed_at': '2026-01-01T00:00:00Z',
  'admitted_count': 0,
  'activated_count': 0,
  'pending_count': 1,
  'readiness': {'state': 'waiting_for_approval'},
  'participants': <Object>[],
  'waiting': <Object>[],
  'requests': <Object>[],
  'history_truncated': false,
};

void main() {
  test(
    'participant request sends the attempt IDs and connection state',
    () async {
      final client = RecordingClient(
        nextResponse: ApiResponse(
          statusCode: 200,
          body: jsonEncode(snapshot()),
        ),
      );
      final repository = ParticipantAdmissionRepository(
        apiService: ClientApi(ApiConfig(client: client)),
      );

      final result = await repository.request(
        sessionSlug: 'session',
        requestId: 'request-1',
        attemptId: 'attempt-1',
        connected: true,
      );

      check(result.version).equals(2);
      check(
        client.requests.single.path,
      ).equals('/api/mobile/protected/rooms/session/admission/request');
      check(
        jsonDecode(client.requests.single.body! as String)
            as Map<String, dynamic>,
      ).deepEquals({
        'request_id': 'request-1',
        'attempt_id': 'attempt-1',
        'connected': true,
      });
    },
  );

  test(
    'keeper approval preserves command and concurrency identifiers',
    () async {
      final client = RecordingClient(
        nextResponse: ApiResponse(
          statusCode: 200,
          body: jsonEncode({
            'command_id': 'command-1',
            'replayed': true,
            'results': <Object>[],
            'partial_failure': false,
            'snapshot': snapshot(),
          }),
        ),
      );
      final repository = KeeperAdmissionRepository(
        apiService: ClientApi(ApiConfig(client: client)),
      );

      final result = await repository.approve(
        sessionSlug: 'session',
        identity: 'guest',
        body: const KeeperDecisionInput(
          commandId: 'command-1',
          requestId: 'request-1',
          attemptId: 'attempt-1',
          expectedVersion: 3,
          expectedRoomVersion: 4,
        ),
      );

      check(result.commandId).equals('command-1');
      check(result.replayed).isTrue();
      check(
        client.requests.single.path,
      ).equals('/api/mobile/protected/rooms/session/admission/guest/approve');
      check(
        jsonDecode(client.requests.single.body! as String)
            as Map<String, dynamic>,
      ).deepEquals({
        'command_id': 'command-1',
        'request_id': 'request-1',
        'attempt_id': 'attempt-1',
        'expected_version': 3,
        'expected_room_version': 4,
      });
    },
  );
}
