import 'dart:async';
import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/features/sessions/admission/session_admission_service.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart'
    as session_state;
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/services/session_packet_router.dart';
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
  Completer<void>? snapshotGate;
  Completer<void>? meGate;
  Completer<void>? meStarted;
  List<String>? recipients;
  bool omitRecipients = false;
  bool nullRecipients = false;
  String? presenceError;
  int? snapshotRoomVersion;
  final requests = <ApiRequest>[];

  Map<String, dynamic> get snapshot => {
    'session_slug': 'session',
    'keeper': room.keeper,
    'room_version': snapshotRoomVersion ?? room.version,
    'room_state': room.toJson(),
    'room_status': RoomStatus.active.value,
    'approval_required': approval,
    'settings_revision': revision,
    'version': version,
    'observed_at': '2026-01-01T00:00:00Z',
    if (!omitRecipients)
      'admitted_recipients': nullRecipients
          ? null
          : recipients ?? [room.keeper, 'activated'],
    if (presenceError != null) 'presence_error': presenceError,
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
      data['readiness'] = const AdmissionReadiness(
        state: ReadinessState.activated,
      ).toJson();
      data['me'] = _participant(
        'keeper',
        state: 'admitted',
        status: 'activated',
      );
      meStarted?.complete();
      meStarted = null;
      await meGate?.future;
      return response(data);
    }
    if (request.method == 'GET') {
      if (snapshotFailureStatus case final status?) {
        return response({
          'code': 'unavailable',
          'message': 'unavailable',
        }, status);
      }
      final data = snapshot;
      await snapshotGate?.future;
      return response(data);
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
                'error': CommandResultError.roomFull.value,
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
    when(() => transport.participants).thenReturn(const [
      ParticipantInfo(sid: 'keeper-sid', identity: 'keeper', name: 'Keeper'),
      ParticipantInfo(
        sid: 'activated-sid',
        identity: 'activated',
        name: 'Activated',
      ),
      ParticipantInfo(
        sid: 'new-keeper-sid',
        identity: 'new-keeper',
        name: 'New Keeper',
      ),
    ]);
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
    'participant updates do not refresh but presence and reconnect do',
    () async {
      await h.refresh();
      final initialRequests = h.backend.requests.length;
      const participant = ParticipantInfo(
        sid: 'sid',
        identity: 'guest',
        name: 'Guest',
      );
      h.service.handleTransportEvent(
        const TransportParticipantUpdated(participant),
      );
      await h.service.synchronized;
      check(h.backend.requests.length).equals(initialRequests);
      check(
        h.service.serverDataRecipients,
      ).isNotNull().unorderedEquals({'keeper', 'activated'});
      h.backend.waiting = [];
      h.backend.version++;
      h.service.handleTransportEvent(
        const TransportParticipantChanged(
          ParticipantInfo(
            sid: 'keeper-sid',
            identity: 'keeper',
            name: 'Keeper',
          ),
          present: false,
        ),
      );
      await h.service.synchronized;
      check(h.service.requests).isEmpty();
      final afterPresence = h.backend.requests.length;
      h.backend.waiting = [_participant('guest')];
      h.backend.version++;
      h.service.handleTransportEvent(
        const TransportConnectionChanged(
          SessionTransportConnectionState.connected,
          reconnected: true,
        ),
      );
      await h.service.synchronized;
      check(h.backend.requests.length).isGreaterThan(afterPresence);
      check(h.service.requests).isNotEmpty();
    },
  );

  test(
    'presence bursts are bounded and preserve immediate and in-flight refreshes',
    () {
      fakeAsync((async) {
        final h = _Harness();
        h.service.sync();
        async.flushMicrotasks();
        final initialRequests = h.backend.requests.length;
        const guest = ParticipantInfo(
          sid: 'sid',
          identity: 'guest',
          name: 'Guest',
        );
        const presence = TransportParticipantChanged(guest, present: true);
        for (var i = 0; i < 20; i++) {
          h.service.handleTransportEvent(presence);
          async.elapse(const Duration(milliseconds: 40));
        }
        check(h.backend.requests.length).equals(initialRequests);
        check(h.service.serverDataRecipients).isNull();
        async.elapse(const Duration(milliseconds: 200));
        check(h.backend.requests.length).equals(initialRequests + 1);

        h.backend.snapshotGate = Completer<void>();
        h.service.handleTransportEvent(
          TransportPacketReceived(
            SessionTransportPacket(
              bytes: const [],
              topic: SessionCommunicationTopics.admission.topic,
            ),
          ),
        );
        async.flushMicrotasks();
        check(h.backend.requests.length).equals(initialRequests + 2);
        h.service.handleTransportEvent(presence);
        h.backend.waiting = [];
        h.backend.version++;
        async.elapse(const Duration(seconds: 1));
        h.backend.snapshotGate!.complete();
        h.backend.snapshotGate = null;
        async.flushMicrotasks();
        check(h.service.requests).isEmpty();
        check(h.backend.requests.length).equals(initialRequests + 3);

        h.service.handleTransportEvent(presence);
        h.service.disconnect();
        async.flushMicrotasks();
        final afterDisconnect = h.backend.requests.length;
        async.elapse(const Duration(seconds: 2));
        check(h.backend.requests.length).equals(afterDisconnect);
        h.service.handleTransportEvent(presence);
        h.service.close();
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 2));
        check(h.backend.requests.length).equals(afterDisconnect);
        h.container.dispose();
      });
    },
  );

  test('presence observes changed keeper authority without waiting', () async {
    await h.refresh();
    h.localRoom = _room('new-keeper', 5);
    h.backend.room = h.localRoom;
    const participant = ParticipantInfo(
      sid: 'sid',
      identity: 'guest',
      name: 'Guest',
    );
    h.service.handleTransportEvent(
      const TransportParticipantChanged(participant, present: true),
    );
    await h.service.synchronized;
    check(h.service.snapshot).isNull();
    check(
      h.service.serverDataRecipients,
    ).isNotNull().unorderedEquals({'new-keeper', 'activated'});
  });

  test(
    'Keeper snapshot exposes waiting, history, permanent declines and room recipients',
    () async {
      await h.refresh();
      check(h.service.error).isNull();
      check(h.service.snapshot?.version).equals(12);
      check(h.service.requests.map((p) => p.identity)).deepEquals(['guest']);
      check(h.service.attempts.map((p) => p.identity)).deepEquals(['old']);
      check(h.service.declined.map((p) => p.identity)).deepEquals(['blocked']);
      check(
        h.service.serverDataRecipients,
      ).isNotNull().unorderedEquals({'keeper', 'activated'});
    },
  );

  test(
    'snapshot recipients require server presence and current transport',
    () async {
      h.backend.recipients = ['keeper', 'activated', 'disconnected'];
      await h.refresh();
      check(
        h.service.serverDataRecipients,
      ).isNotNull().unorderedEquals({'keeper', 'activated'});
      check(h.backend.requests).length.equals(1);
      for (final unavailable in ['omitted', 'null', 'error']) {
        h.backend.omitRecipients = unavailable == 'omitted';
        h.backend.nullRecipients = unavailable == 'null';
        h.backend.presenceError = unavailable == 'error' ? 'unavailable' : null;
        await h.refresh();
        check(h.service.serverDataRecipients).isNull();
        check(h.service.admittedIdentities).isEmpty();
        check(h.service.requests).isNotEmpty();
      }
    },
  );

  test('stale or inconsistent room versions fail closed', () async {
    await h.refresh();
    h.localRoom = _room('keeper', 5);
    await h.refresh();
    check(h.service.serverDataRecipients).isNull();
    check(h.service.snapshot).isNull();
    h.localRoom = _room('keeper', 4);
    h.backend.snapshotRoomVersion = 5;
    await h.refresh();
    check(h.service.serverDataRecipients).isNull();
    check(h.service.snapshot).isNull();
    h.backend.snapshotRoomVersion = null;
    h.backend.room = _room('keeper', 6);
    await h.refresh();
    check(h.localRoom.version).equals(6);
    check(h.service.serverDataRecipients).isNotNull();
  });

  for (final action in ['approve', 'decline', 'permanent']) {
    test('$action sends current attempt and room versions', () async {
      await h.refresh();
      final guest = h.service.requests.single;
      await h.service.decide(
        guest,
        action == 'approve',
        permanently: action == 'permanent',
      );
      check(h.service.error).isNull();
      final request = h.backend.commands.single;
      check(
        request.path,
      ).endsWith(action == 'approve' ? '/guest/approve' : '/guest/decline');
      final body = h.body(request);
      check(
        body['command_id'],
      ).isA<String>().matchesPattern(RegExp(r'^[0-9a-f-]{36}$'));
      check(body['request_id']).equals('request-guest');
      check(body['attempt_id']).equals('attempt-guest');
      check(body['expected_version']).equals(7);
      check(body['expected_room_version']).equals(4);
      if (action != 'approve') {
        check(body['permanent']).equals(action == 'permanent');
      }
      check(h.service.requests).isEmpty();
    });
  }

  test('admit all uses one versioned batch command', () async {
    h.backend.waiting.add(_participant('another'));
    await h.refresh();
    check(await h.service.admitAll()).isTrue();
    final request = h.backend.commands.single;
    check(request.path).endsWith('/admission/admit-all');
    check(h.body(request)['expected_room_version']).equals(4);
    check(h.service.requests).isEmpty();
  });

  test('settings only change after successful server response', () async {
    await h.refresh();
    h.backend.failureStatus = 409;
    await h.service.setApprovalRequired(false);
    check(h.service.approvalRequired).isTrue();
    check(h.service.error).isNotNull();
    h.backend.failureStatus = null;
    await h.service.setApprovalRequired(false);
    check(h.service.approvalRequired).isFalse();
    check(h.backend.approval).isFalse();
    final body = h.body(h.backend.commands.last);
    check(body['expected_revision']).equals(9);
    check(body['expected_room_version']).equals(4);
  });

  test(
    '403 from old Keeper discovers reassignment without a room request or stale decision',
    () async {
      h.backend.approval = false;
      await h.refresh();
      final guest = h.service.requests.single;
      check(h.service.approvalRequired).isFalse();
      h.backend.room = _room('new-keeper', 5);
      h.backend.snapshotFailureStatus = 403;
      h.backend.meGate = Completer<void>();
      h.backend.meStarted = Completer<void>();
      final started = h.backend.meStarted!.future;
      final decision = h.service.decide(guest, true);
      await started;
      check(h.service.snapshot).isNull();
      check(h.service.approvalRequired).isTrue();
      h.backend.meGate!.complete();
      await decision;
      await h.service.synchronized;
      check(h.localRoom.keeper).equals('new-keeper');
      check(h.service.snapshot).isNull();
      check(h.service.approvalRequired).isFalse();
      check(h.backend.commands).isEmpty();
      check(h.backend.requests.any((r) => r.path.endsWith('/state'))).isFalse();
    },
  );

  test(
    'participant discovers promotion and refreshes Keeper authority',
    () async {
      when(() => h.transport.localIdentity).thenReturn('new-keeper');
      h.backend.room = _room('new-keeper', 5);
      h.backend.approval = false;
      await h.refresh();
      await h.service.synchronized;
      check(h.localRoom.keeper).equals('new-keeper');
      check(h.service.snapshot).isNotNull();
      check(h.service.approvalRequired).isFalse();
      check(h.backend.requests.any((r) => r.path.endsWith('/state'))).isFalse();
    },
  );

  test('reassignment at the same room version is rejected', () async {
    when(() => h.transport.localIdentity).thenReturn('guest');
    h.backend.room = _room('new-keeper', 4);
    h.backend.approval = false;
    await h.refresh();
    check(h.localRoom.keeper).equals('keeper');
    check(h.service.approvalRequired).isTrue();
    check(h.service.serverDataRecipients).isNull();
    check(h.service.error).isNotNull();
  });

  test('delayed reassignment cannot overwrite newer local authority', () async {
    when(() => h.transport.localIdentity).thenReturn('guest');
    h.backend.room = _room('new-keeper', 5);
    h.backend.approval = false;
    h.backend.meGate = Completer<void>();
    h.backend.meStarted = Completer<void>();
    final started = h.backend.meStarted!.future;
    h.service.sync();
    await started;
    h.localRoom = _room('later-keeper', 6);
    h.backend.meGate!.complete();
    await h.service.synchronized;
    check(h.localRoom.keeper).equals('later-keeper');
    check(h.service.approvalRequired).isTrue();
    check(h.service.serverDataRecipients).isNull();
  });

  test('stale request is not submitted after refresh', () async {
    await h.refresh();
    final old = h.service.requests.single;
    h.backend.waiting = [_participant('guest')..['attempt_id'] = 'replacement'];
    await h.service.decide(old, true);
    check(h.backend.commands).isEmpty();
    check(h.service.error).isNotNull();
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
    clearInteractions(h.session);
    check(h.service.snapshot).isNull();
    check(h.service.hasUnresolvedCommand).isFalse();
    check(h.service.requests).isEmpty();
    check(h.service.attempts).isEmpty();
    check(h.service.declined).isEmpty();
    check(h.service.admittedIdentities).isEmpty();
    check(h.service.serverDataRecipients).isNull();
    verifyNever(() => h.session.updateAdmittedMediaRecipients(any()));
    h.service.sync();
    verify(() => h.session.updateAdmittedMediaRecipients(<String>{})).called(1);
    h.backend.gate!.complete();
    await decision;
    check(h.service.snapshot).isNull();
    await h.refresh();
    check(h.service.snapshot).isNull();
    check(
      h.service.serverDataRecipients,
    ).isNotNull().unorderedEquals({'new-keeper', 'activated'});
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
      when(() => replacement.participants).thenReturn(h.transport.participants);
      when(() => h.session.transport).thenReturn(replacement);
      check(h.service.snapshot).isNull();
      check(h.service.requests).isEmpty();
      check(h.service.serverDataRecipients).isNull();
      check(h.service.hasUnresolvedCommand).isTrue();
      h.backend.waiting = [];
      h.backend.failureStatus = null;
      await h.refresh();
      check(h.service.requests).isEmpty();
      check(await h.service.retryUnresolved()).isTrue();
      check(h.backend.commands).length.equals(2);
      check(h.body(h.backend.commands.last)).deepEquals(oldBody);
      check(h.service.hasUnresolvedCommand).isFalse();
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
      when(() => replacement.participants).thenReturn(h.transport.participants);
      when(() => h.session.transport).thenReturn(replacement);
      check(h.service.hasUnresolvedCommand).isTrue();
      final retry = h.service.retryUnresolved();
      h.backend.gate!.complete();
      await decision;
      check(await retry).isTrue();
      check(h.backend.commands).length.equals(2);
      check(h.body(h.backend.commands.last)).deepEquals(original);
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
    check(h.backend.commands).length.equals(1);
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
    check(unresolvedWhileInFlight).isFalse();
  });

  test('uncertain outcome retries the same command and payload', () async {
    await h.refresh();
    final guest = h.service.requests.single;
    h.backend.failureStatus = 503;
    await h.service.decide(guest, true);
    check(h.service.error).isNotNull().contains('unknown');
    check(h.service.hasUnresolvedCommand).isTrue();
    h.backend.failureStatus = null;
    await h.service.decide(guest, true);
    check(h.backend.commands).length.equals(2);
    check(
      h.body(h.backend.commands.last),
    ).deepEquals(h.body(h.backend.commands.first));
    check(h.service.error).isNull();
    check(h.service.hasUnresolvedCommand).isFalse();
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
      check(h.service.approvalRequired).isFalse();
      check(h.service.hasUnresolvedCommand).isTrue();
      check(await h.service.retryUnresolved()).isTrue();
      check(h.body(h.backend.commands.last)).deepEquals(oldBody);
      check(h.service.hasUnresolvedCommand).isFalse();
    },
  );

  test(
    'snapshot refresh failure hides stale queue and supports manual retry',
    () async {
      await h.refresh();
      check(h.service.requests).isNotEmpty();
      h.backend.snapshotFailureStatus = 503;
      await h.refresh();
      check(h.service.snapshot).isNull();
      check(h.service.requests).isEmpty();
      check(h.service.serverDataRecipients).isNull();
      check(h.service.error).isNotNull().contains('refresh');
      h.backend.snapshotFailureStatus = null;
      await h.refresh();
      check(h.service.requests).isNotEmpty();
      check(h.service.error).isNull();
    },
  );

  test('participant reads only me and cannot submit Keeper commands', () async {
    when(() => h.transport.localIdentity).thenReturn('guest');
    await h.refresh();
    check(h.service.snapshot).isNull();
    check(
      h.service.serverDataRecipients,
    ).isNotNull().unorderedEquals({'keeper', 'activated'});
    check(
      h.backend.requests.any((r) => r.path.endsWith('/admission/me')),
    ).isTrue();
    check(
      h.backend.requests.any((r) => r.path.endsWith('/admission')),
    ).isFalse();
    check(await h.service.admitAll()).isFalse();
    check(h.backend.commands).isEmpty();
  });

  test('partial batch failure is surfaced without claiming success', () async {
    await h.refresh();
    h.backend.partial = true;
    check(await h.service.admitAll()).isFalse();
    check(h.service.error).isNotNull().contains('room_full');
    check(h.service.requests.map((p) => p.identity)).deepEquals(['guest']);
  });
}
