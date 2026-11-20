import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/features/sessions/admission/session_admission_service.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart'
    as session_state;
import 'package:totem_core/features/sessions/transport/session_transport.dart';

import '../../../setup.dart';
import '../session_test_mocks.dart';

class _Session extends Mock implements SessionController {}

class _Transport extends Mock implements SessionTransport {}

RoomState _room(String keeper, int version) => RoomState(
  keeper: keeper,
  nextSpeaker: const Omittable(''),
  currentSpeaker: const Omittable(''),
  status: RoomStatus.active,
  turnState: TurnState.idle,
  sessionSlug: 'session',
  statusDetail: const RoomStateStatusDetailActive(ActiveDetail()),
  talkingOrder: const ['activated'],
  version: version,
  roundNumber: 1,
);

Map<String, dynamic> _participant(
  String identity, {
  String state = 'none',
  String status = 'pending',
}) => {
  'identity': identity,
  'user': {
    'profile_avatar_type': 'boring',
    'date_created': '2026-01-01T00:00:00Z',
  },
  'admission_state': state,
  'admission_version': 3,
  'request_id': 'request-$identity',
  'attempt_id': 'attempt-$identity',
  'attempt_version': 7,
  'status': status,
  'connection_state': 'connected',
  'eligible': true,
  'returning': false,
  'session_started': false,
  'late_arrival': false,
  'permission_status': 'applied',
  'permission_revision': 1,
  'last_error': null,
};

class _Backend implements ApiClient {
  RoomState room = _room('keeper', 4);
  List<Map<String, dynamic>> waiting = [_participant('guest')];
  List<Map<String, dynamic>> history = [
    _participant('old', status: 'declined'),
  ];
  List<Map<String, dynamic>> participants = [
    _participant(
      'blocked',
      state: 'permanently_declined',
      status: 'permanently_declined',
    ),
  ];
  bool approval = true;
  int revision = 9;
  int version = 12;
  int? failureStatus;
  int? snapshotFailureStatus;
  bool partial = false;
  Completer<void>? gate;
  Completer<void>? started;
  final requests = <ApiRequest>[];

  Map<String, dynamic> get snapshot => {
    'session_slug': 'session',
    'keeper': room.keeper,
    'room_version': room.version,
    'room_status': 'active',
    'approval_required': approval,
    'settings_revision': revision,
    'version': version,
    'observed_at': '2026-01-01T00:00:00Z',
    'admitted_count': 0,
    'activated_count': 0,
    'pending_count': waiting.length,
    'participants': participants,
    'waiting': waiting,
    'requests': history,
    'history_truncated': false,
  };

  ApiResponse response(Object body, [int status = 200]) =>
      ApiResponse(statusCode: status, body: jsonEncode(body));

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    if (request.path.endsWith('/state')) return response(room.toJson());
    if (request.path.endsWith('/admission/me')) {
      final data = Map<String, dynamic>.from(snapshot)
        ..remove('participants')
        ..remove('waiting')
        ..remove('requests')
        ..remove('history_truncated');
      data['me'] = _participant(
        'keeper',
        state: 'admitted',
        status: 'activated',
      );
      return response(data);
    }
    if (request.method == 'GET') {
      if (snapshotFailureStatus case final status?) {
        return response({
          'code': 'unavailable',
          'message': 'unavailable',
        }, status);
      }
      return response(snapshot);
    }
    final body = jsonDecode(request.body! as String) as Map<String, dynamic>;
    started?.complete();
    started = null;
    await gate?.future;
    if (failureStatus case final status?) {
      return response({'code': 'stale_version', 'message': 'stale'}, status);
    }
    if (request.path.endsWith('/settings')) {
      approval = body['approval_required'] as bool;
      revision++;
    } else if (request.path.endsWith('/admit-all')) {
      if (!partial) waiting = [];
    } else if (request.path.endsWith('/approve') ||
        request.path.endsWith('/decline')) {
      waiting = [];
    }
    version++;
    return response({
      'command_id': body['command_id'],
      'replayed': false,
      'partial_failure': partial,
      'results': partial
          ? [
              {
                'identity': 'guest',
                'outcome': 'pending',
                'error': 'room_full',
                'participant': null,
              },
            ]
          : <Object>[],
      'snapshot': snapshot,
    });
  }

  List<ApiRequest> get commands =>
      requests.where((r) => r.method != 'GET').toList();
  @override
  Uri get baseUrl => Uri.parse('https://test.example.com');
  @override
  Future<void> close() async {}
  @override
  Future<StreamedApiResponse> sendStreaming(ApiRequest request) =>
      throw UnsupportedError('streaming');
}

class _Harness {
  _Harness() {
    registerFallbackValue(_room('keeper', 4));
    registerFallbackValue(<String>{});
    when(() => session.transport).thenReturn(transport);
    when(() => transport.localIdentity).thenReturn('keeper');
    when(() => session.admissionState).thenReturn(state);
    when(
      () => state.connectionState,
    ).thenReturn(session_state.RoomConnectionState.connected);
    when(() => state.roomState).thenAnswer((_) => localRoom);
    when(() => session.applyRoomState(any())).thenAnswer((invocation) {
      localRoom = invocation.positionalArguments.single as RoomState;
    });
    when(() => session.updateAdmittedMediaRecipients(any())).thenReturn(null);
    when(() => session.session).thenReturn(null);
    when(() => session.options).thenReturn(
      const session_state.SessionOptions(
        sessionSlug: 'session',
        token: '',
        cameraEnabled: false,
        microphoneEnabled: false,
        speakerEnabled: true,
        cameraOptions: SessionController.defaultCameraCaptureOptions,
      ),
    );
    final provider = Provider<SessionAdmissionService>(
      (ref) => SessionAdmissionService(ref, session),
    );
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        apiServiceProvider.overrideWithValue(
          ClientApi(ApiConfig(client: backend)),
        ),
      ],
    );
    service = container.read(provider);
  }

  final backend = _Backend();
  final session = _Session();
  final state = MockSessionRoomState();
  final transport = _Transport();
  RoomState localRoom = _room('keeper', 4);
  late final ProviderContainer container;
  late final SessionAdmissionService service;

  Future<void> refresh() async {
    service.sync();
    await service.synchronized;
  }

  Future<void> dispose() async {
    await service.close();
    container.dispose();
  }

  Map<String, dynamic> body(ApiRequest request) =>
      jsonDecode(request.body! as String) as Map<String, dynamic>;
}

void main() {
  setupAppConfig();
  late _Harness h;
  setUp(() {
    h = _Harness();
  });
  tearDown(() async {
    await h.dispose();
  });

  test(
    'Keeper snapshot exposes waiting, history, permanent declines and room recipients',
    () async {
      await h.refresh();
      expect(h.service.error, isNull);
      expect(h.service.snapshot?.version, 12);
      expect(h.service.requests.map((p) => p.identity), ['guest']);
      expect(h.service.attempts.map((p) => p.identity), ['old']);
      expect(h.service.declined.map((p) => p.identity), ['blocked']);
      expect(h.service.serverDataRecipients, {'keeper', 'activated'});
    },
  );

  for (final action in ['approve', 'decline', 'permanent']) {
    test('$action sends current attempt and room versions', () async {
      await h.refresh();
      final guest = h.service.requests.single;
      await h.service.decide(
        guest,
        action == 'approve',
        permanently: action == 'permanent',
      );
      expect(h.service.error, isNull);
      final request = h.backend.commands.single;
      expect(
        request.path,
        endsWith(action == 'approve' ? '/guest/approve' : '/guest/decline'),
      );
      final body = h.body(request);
      expect(body['command_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(body['request_id'], 'request-guest');
      expect(body['attempt_id'], 'attempt-guest');
      expect(body['expected_version'], 7);
      expect(body['expected_room_version'], 4);
      if (action != 'approve') expect(body['permanent'], action == 'permanent');
      expect(h.service.requests, isEmpty);
    });
  }

  test('admit all uses one versioned batch command', () async {
    h.backend.waiting.add(_participant('another'));
    await h.refresh();
    expect(await h.service.admitAll(), isTrue);
    final request = h.backend.commands.single;
    expect(request.path, endsWith('/admission/admit-all'));
    expect(h.body(request)['expected_room_version'], 4);
    expect(h.service.requests, isEmpty);
  });

  test('settings only change after successful server response', () async {
    await h.refresh();
    h.backend.failureStatus = 409;
    await h.service.setApprovalRequired(false);
    expect(h.service.approvalRequired, isTrue);
    expect(h.service.error, isNotNull);
    h.backend.failureStatus = null;
    await h.service.setApprovalRequired(false);
    expect(h.service.approvalRequired, isFalse);
    expect(h.backend.approval, isFalse);
    final body = h.body(h.backend.commands.last);
    expect(body['expected_revision'], 9);
    expect(body['expected_room_version'], 4);
  });

  test('stale request is not submitted after refresh', () async {
    await h.refresh();
    final old = h.service.requests.single;
    h.backend.waiting = [_participant('guest')..['attempt_id'] = 'replacement'];
    await h.service.decide(old, true);
    expect(h.backend.commands, isEmpty);
    expect(h.service.error, isNotNull);
  });

  test('reassignment fences a delayed command response', () async {
    await h.refresh();
    final guest = h.service.requests.single;
    h.backend.gate = Completer<void>();
    h.backend.started = Completer<void>();
    final started = h.backend.started!.future;
    final decision = h.service.decide(guest, true);
    await started;
    h.localRoom = _room('new-keeper', 5);
    h.backend.room = h.localRoom;
    expect(h.service.snapshot, isNull);
    expect(h.service.hasUnresolvedCommand, isFalse);
    expect(h.service.requests, isEmpty);
    expect(h.service.attempts, isEmpty);
    expect(h.service.declined, isEmpty);
    expect(h.service.admittedIdentities, isEmpty);
    expect(h.service.serverDataRecipients, isNull);
    verify(() => h.session.updateAdmittedMediaRecipients(<String>{})).called(1);
    h.backend.gate!.complete();
    await decision;
    expect(h.service.snapshot, isNull);
    await h.refresh();
    expect(h.service.snapshot, isNull);
    expect(h.service.serverDataRecipients, {'new-keeper', 'activated'});
  });

  test(
    'transport replacement retains unresolved command for explicit retry',
    () async {
      await h.refresh();
      final guest = h.service.requests.single;
      h.backend.failureStatus = 503;
      await h.service.decide(guest, true);
      final oldBody = h.body(h.backend.commands.single);
      final replacement = _Transport();
      when(() => replacement.localIdentity).thenReturn('keeper');
      when(() => h.session.transport).thenReturn(replacement);
      expect(h.service.snapshot, isNull);
      expect(h.service.requests, isEmpty);
      expect(h.service.serverDataRecipients, isNull);
      expect(h.service.hasUnresolvedCommand, isTrue);
      h.backend.waiting = [];
      h.backend.failureStatus = null;
      await h.refresh();
      expect(h.service.requests, isEmpty);
      expect(await h.service.retryUnresolved(), isTrue);
      expect(h.backend.commands, hasLength(2));
      expect(h.body(h.backend.commands.last), oldBody);
      expect(h.service.hasUnresolvedCommand, isFalse);
    },
  );

  test(
    'transport replacement while command is in flight retains its ID',
    () async {
      await h.refresh();
      final guest = h.service.requests.single;
      h.backend.gate = Completer<void>();
      h.backend.started = Completer<void>();
      final started = h.backend.started!.future;
      final decision = h.service.decide(guest, true);
      await started;
      final original = h.body(h.backend.commands.single);
      final replacement = _Transport();
      when(() => replacement.localIdentity).thenReturn('keeper');
      when(() => h.session.transport).thenReturn(replacement);
      expect(h.service.hasUnresolvedCommand, isTrue);
      final retry = h.service.retryUnresolved();
      h.backend.gate!.complete();
      await decision;
      expect(await retry, isTrue);
      expect(h.backend.commands, hasLength(2));
      expect(h.body(h.backend.commands.last), original);
    },
  );

  test('rapid duplicate actions send just one command', () async {
    await h.refresh();
    final guest = h.service.requests.single;
    h.backend.gate = Completer<void>();
    h.backend.started = Completer<void>();
    final started = h.backend.started!.future;
    final first = h.service.decide(guest, true);
    await started;
    final second = h.service.decide(guest, true);
    h.backend.gate!.complete();
    await Future.wait([first, second]);
    expect(h.backend.commands, hasLength(1));
  });

  test('in-flight approval is not an unresolved command', () async {
    await h.refresh();
    final guest = h.service.requests.single;
    h.backend.gate = Completer<void>();
    h.backend.started = Completer<void>();
    final started = h.backend.started!.future;
    final decision = h.service.decide(guest, true);
    await started;
    final unresolvedWhileInFlight = h.service.hasUnresolvedCommand;
    h.backend.gate!.complete();
    await decision;
    expect(unresolvedWhileInFlight, isFalse);
  });

  test('uncertain outcome retries the same command and payload', () async {
    await h.refresh();
    final guest = h.service.requests.single;
    h.backend.failureStatus = 503;
    await h.service.decide(guest, true);
    expect(h.service.error, contains('unknown'));
    expect(h.service.hasUnresolvedCommand, isTrue);
    h.backend.failureStatus = null;
    await h.service.decide(guest, true);
    expect(h.backend.commands, hasLength(2));
    expect(h.body(h.backend.commands.last), h.body(h.backend.commands.first));
    expect(h.service.error, isNull);
    expect(h.service.hasUnresolvedCommand, isFalse);
  });

  test(
    'explicit retry works when the settings value already changed',
    () async {
      await h.refresh();
      h.backend.failureStatus = 503;
      await h.service.setApprovalRequired(false);
      final oldBody = h.body(h.backend.commands.single);
      h.backend.approval = false;
      h.backend.revision++;
      h.backend.version++;
      h.backend.failureStatus = null;
      await h.refresh();
      expect(h.service.approvalRequired, isFalse);
      expect(h.service.hasUnresolvedCommand, isTrue);
      expect(await h.service.retryUnresolved(), isTrue);
      expect(h.body(h.backend.commands.last), oldBody);
      expect(h.service.hasUnresolvedCommand, isFalse);
    },
  );

  test(
    'snapshot refresh failure hides stale queue and supports manual retry',
    () async {
      await h.refresh();
      expect(h.service.requests, isNotEmpty);
      h.backend.snapshotFailureStatus = 503;
      await h.refresh();
      expect(h.service.snapshot, isNull);
      expect(h.service.requests, isEmpty);
      expect(h.service.serverDataRecipients, isNull);
      expect(h.service.error, contains('refresh'));
      h.backend.snapshotFailureStatus = null;
      await h.refresh();
      expect(h.service.requests, isNotEmpty);
      expect(h.service.error, isNull);
    },
  );

  test('participant reads only me and cannot submit Keeper commands', () async {
    when(() => h.transport.localIdentity).thenReturn('guest');
    await h.refresh();
    expect(h.service.snapshot, isNull);
    expect(h.service.serverDataRecipients, {'keeper', 'activated'});
    expect(
      h.backend.requests.any((r) => r.path.endsWith('/admission/me')),
      isTrue,
    );
    expect(
      h.backend.requests.any((r) => r.path.endsWith('/admission')),
      isFalse,
    );
    expect(await h.service.admitAll(), isFalse);
    expect(h.backend.commands, isEmpty);
  });

  test('partial batch failure is surfaced without claiming success', () async {
    await h.refresh();
    h.backend.partial = true;
    expect(await h.service.admitAll(), isFalse);
    expect(h.service.error, contains('room_full'));
    expect(h.service.requests.map((p) => p.identity), ['guest']);
  });
}
