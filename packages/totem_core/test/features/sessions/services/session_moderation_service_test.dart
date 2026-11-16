import 'dart:async';
import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/services/session_commands.dart';
import 'package:totem_core/features/sessions/services/session_moderation_service.dart';
import 'package:totem_core/features/sessions/services/session_packet_router.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

import '../transport/fake_session_transport.dart';

const _keeper = ParticipantInfo(
  sid: 'keeper',
  identity: 'keeper',
  name: 'Keeper',
);
const _other = ParticipantInfo(sid: 'other', identity: 'other', name: 'Other');

RoomState _room({int version = 10}) => RoomState(
  sessionSlug: 'session',
  version: version,
  status: RoomStatus.active,
  turnState: TurnState.idle,
  statusDetail: const RoomStateStatusDetailActive(ActiveDetail()),
  talkingOrder: const [],
  keeper: 'keeper',
  roundNumber: 1,
);

SessionTransportPacket _removal({
  ParticipantInfo? sender = _keeper,
  String target = 'local',
  RemoveReason reason = RemoveReason.remove,
}) => SessionTransportPacket(
  topic: SessionCommunicationTopics.participantRemoved.topic,
  sender: sender,
  bytes: utf8.encode(
    jsonEncode(
      RemoveParticipantPayload(identity: target, reason: reason).toJson(),
    ),
  ),
);

class _Backend implements SessionModerationBackend {
  _Backend(this.removeAction, this.banAction, this.events);
  final List<String> events;
  final Future<void> Function(String) removeAction;
  final Future<RoomState> Function(int, String) banAction;
  @override
  Future<void> remove(String identity) => removeAction(identity);
  @override
  Future<RoomState> ban(int version, String identity) =>
      banAction(version, identity);
  @override
  Future<RoomState> unban(int version, String identity) =>
      banAction(version, identity);
  @override
  Future<void> mute(String identity) async {
    events.add('mute:$identity');
  }

  @override
  Future<void> disableCamera(String identity) async {
    events.add('camera:$identity');
  }

  @override
  Future<void> muteEveryone() async {}
}

class _Harness {
  _Harness() {
    connection
      ..localIdentity = 'local'
      ..connectionState = SessionTransportConnectionState.connected;
    service = SessionModerationService(
      backend: _Backend(
        (identity) async {
          events.add('backend:$identity');
          await remove?.call(identity);
        },
        (version, identity) async {
          events.add('ban:$identity:$version');
          return await ban?.call(version, identity) ??
              _room(version: version + 1);
        },
        events,
      ),
      state: () => SessionRoomState(
        connection: const ConnectionState(
          phase: SessionPhase.connected,
          state: RoomConnectionState.connected,
        ),
        participants: const ParticipantsState(),
        turn: SessionTurnState(roomState: room),
      ),
      isKeeper: () => keeper,
      transport: () => connection,
      applyState: (next) {
        applied.add(next);
        room = next;
      },
      prepareRemoval: (identity) async {
        events.add('prepare');
        final revoke = await prepare?.call() ?? _revoke;
        return PreparedAdmissionRemoval(
          commit: () => revoke(identity),
          reject: () async {
            events.add('rejected');
          },
          unknown: () async {
            events.add('unknown');
          },
        );
      },
      markRemoved: removed.add,
      leave: () async {
        leaves++;
        await leaving?.call();
      },
      onError: (error, _) {
        errors.add(error);
        failureReported?.complete();
      },
      captureValidity: () {
        final attempt = generation;
        return () => attempt == generation;
      },
    );
  }
  final connection = FakeSessionTransport();
  late final SessionModerationService service;
  bool keeper = true;
  int generation = 0;
  int leaves = 0;
  RoomState room = _room();
  final events = <String>[];
  final removed = <RemoveReason>[];
  final applied = <RoomState>[];
  final errors = <Object>[];
  Future<AdmissionRevocation> Function()? prepare;
  Future<void> Function(String)? remove;
  Future<RoomState> Function(int, String)? ban;
  Future<void> Function()? leaving;
  Completer<void>? failureReported;
  Future<void> _revoke(String identity) async {
    events.add('revoke:$identity');
  }

  Future<void> dispose() async {
    service.dispose();
    await connection.dispose();
  }
}

void main() {
  test(
    'mute and camera restriction proceed while removal is pending',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final started = Completer<void>();
      final finish = Completer<void>();
      h.remove = (_) {
        started.complete();
        return finish.future;
      };
      final removal = h.service.removeParticipant('participant');
      await started.future;
      await h.service.muteParticipant('other');
      await h.service.disableParticipantCamera('other');
      check(h.events).contains('mute:other');
      check(h.events).contains('camera:other');
      finish.complete();
      await removal;
      check(h.events).contains('revoke:participant');
    },
  );
  for (final serverOriginated in [false, true]) {
    test(
      'authorized removal marks the local participant and leaves exactly once (server: $serverOriginated)',
      () async {
        final h = _Harness();
        addTearDown(h.dispose);
        final packet = _removal(sender: serverOriginated ? null : _keeper);
        h.service
          ..receive(packet)
          ..receive(packet)
          ..receive(_removal(reason: RemoveReason.ban));

        check(h.removed).deepEquals([RemoveReason.remove]);
        check(h.leaves).equals(1);
        check(h.errors).isEmpty();
      },
    );
  }

  test(
    'wrong senders, targets, topics, and malformed packets cannot remove the local participant',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.service
        ..receive(_removal(sender: _other))
        ..receive(_removal(target: 'other'))
        ..receive(
          SessionTransportPacket(
            topic: SessionCommunicationTopics.chat.topic,
            bytes: _removal().bytes,
            sender: _keeper,
          ),
        )
        ..receive(
          SessionTransportPacket(
            topic: SessionCommunicationTopics.participantRemoved.topic,
            bytes: [0xff],
            sender: _keeper,
          ),
        );

      check(h.removed).isEmpty();
      check(h.leaves).equals(0);
      check(h.errors).length.equals(1);
      h.service.receive(_removal());
      check(h.removed).deepEquals([RemoveReason.remove]);
      check(h.leaves).equals(1);
    },
  );

  test(
    'removal cleanup failure is reported without replaying the removal transition',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final failure = StateError('disconnect failed');
      h
        ..failureReported = Completer<void>()
        ..leaving = () async => throw failure;

      h.service.receive(_removal());
      await h.failureReported!.future;
      h.service.receive(_removal());

      check(h.errors.single).identicalTo(failure);
      check(h.removed).length.equals(1);
      check(h.leaves).equals(1);
    },
  );

  test(
    'prepared recovery is acquired before the backend can remove a participant',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final preparing = Completer<void>();
      final prepared = Completer<AdmissionRevocation>();
      h.prepare = () {
        preparing.complete();
        return prepared.future;
      };
      final removing = h.service.removeParticipant('participant');
      await preparing.future;
      check(h.events).deepEquals(['prepare']);
      prepared.complete((String identity) async {
        h.events.add('revoke:$identity');
      });
      await removing;

      check(
        h.events,
      ).deepEquals(['prepare', 'backend:participant', 'revoke:participant']);
    },
  );

  test(
    'unavailable admission recovery refuses removal before the backend mutation',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.prepare = () async => throw StateError('recovery unavailable');

      await check(
        h.service.removeParticipant('participant'),
      ).throws<StateError>();

      check(h.events).deepEquals(['prepare']);
    },
  );

  test(
    'backend removal failure leaves admission permissions unchanged',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final failure = AppNetworkException.noConnection();
      h.remove = (_) async => throw failure;

      await check(
        h.service.removeParticipant('participant'),
      ).throws<SessionCommandException>();

      check(h.events).deepEquals(['prepare', 'backend:participant', 'unknown']);
      check(
        h.service.lastFailure?.kind,
      ).equals(SessionCommandFailureKind.unknownOutcome);
      check(
        (h.service.lastFailure!.error as SessionCommandException).cause,
      ).identicalTo(failure);
    },
  );

  test(
    'definitive backend rejection clears the prepared intent without revoking',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      const failure = ApiError<RoomState, RoomErrorResponse>(
        statusCode: 403,
        error: RoomErrorResponse(
          code: ErrorCode.notKeeper,
          message: 'Rejected',
        ),
      );
      h.remove = (_) async => throw failure;
      await check(
        h.service.removeParticipant('participant'),
      ).throws<ApiError<RoomState, RoomErrorResponse>>();
      check(
        h.events,
      ).deepEquals(['prepare', 'backend:participant', 'rejected']);
    },
  );

  test(
    'timeout retains unknown outcome and overlapping removal never resends',
    () {
      fakeAsync((clock) {
        final h = _Harness();
        addTearDown(h.dispose);
        final backend = Completer<void>();
        h.remove = (_) => backend.future;
        Object? failure;
        h.service
            .removeParticipant('participant')
            .then(
              (_) {},
              onError: (Object error) {
                failure = error;
              },
            );
        clock.flushMicrotasks();
        Object? overlapping;
        // Pump the first command before attempting the overlapping command.
        h.service
            .removeParticipant('participant')
            .then(
              (_) {},
              onError: (Object error) {
                overlapping = error;
              },
            );
        clock.flushMicrotasks();
        check(overlapping).isA<SessionCommandException>();
        clock
          ..elapse(const Duration(seconds: 20))
          ..flushMicrotasks();
        check(
          (failure! as SessionCommandException).kind,
        ).equals(SessionCommandFailureKind.unknownOutcome);
        check(
          h.events,
        ).deepEquals(['prepare', 'backend:participant', 'unknown']);
        backend.complete();
        clock.flushMicrotasks();
        check(
          h.events,
        ).deepEquals(['prepare', 'backend:participant', 'unknown']);
      });
    },
  );

  test(
    'backend success still finishes its captured revocation journal after service disposal',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final backendStarted = Completer<void>();
      final backend = Completer<void>();
      h.remove = (_) {
        backendStarted.complete();
        return backend.future;
      };
      final removing = h.service.removeParticipant('participant');
      await backendStarted.future;
      h.service.dispose();
      backend.complete();
      await removing;

      check(
        h.events,
      ).deepEquals(['prepare', 'backend:participant', 'revoke:participant']);
      h.service.receive(_removal());
      check(h.removed).isEmpty();
      check(h.leaves).equals(0);
    },
  );

  test(
    'persistence failure after backend success remains an explicit partial success',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      final failure = Exception('roster persistence failed');
      h.prepare = () async => (String identity) async {
        h.events.add('revoke:$identity');
        throw failure;
      };

      await check(
        h.service.removeParticipant('participant'),
      ).throws<Exception>();

      check(
        h.events,
      ).deepEquals(['prepare', 'backend:participant', 'revoke:participant']);
      check(
        h.service.lastFailure?.kind,
      ).equals(SessionCommandFailureKind.partialSuccess);
      check(h.service.lastFailure?.error).identicalTo(failure);
    },
  );

  for (final replacedAttempt in [false, true]) {
    test(
      'ban responses cannot overwrite a newer room or attempt (replacement: $replacedAttempt)',
      () async {
        final h = _Harness();
        addTearDown(h.dispose);
        final started = Completer<void>();
        final response = Completer<RoomState>();
        h.ban = (_, _) {
          started.complete();
          return response.future;
        };
        final banning = h.service.banParticipant('participant');
        final rejected = replacedAttempt
            ? check(banning).throws<SessionCommandException>()
            : null;
        await started.future;
        final newer = _room(version: 20);
        if (replacedAttempt) {
          h.generation++;
        } else {
          h.room = newer;
        }
        response.complete(_room(version: replacedAttempt ? 30 : 11));
        if (rejected != null) {
          await rejected;
        } else {
          await banning;
        }

        check(h.applied).isEmpty();
        if (!replacedAttempt) check(h.room).identicalTo(newer);
        if (replacedAttempt) {
          check(
            h.service.lastFailure?.kind,
          ).equals(SessionCommandFailureKind.superseded);
        } else {
          check(h.service.lastFailure).isNull();
        }
      },
    );
  }

  test('participants cannot execute moderation commands', () async {
    final h = _Harness()..keeper = false;
    addTearDown(h.dispose);

    await check(
      h.service.removeParticipant('other'),
    ).throws<SessionCommandException>();
    await check(
      h.service.banParticipant('other'),
    ).throws<SessionCommandException>();

    check(h.events).isEmpty();
    check(
      h.service.lastFailure?.kind,
    ).equals(SessionCommandFailureKind.unauthorized);
  });
}
