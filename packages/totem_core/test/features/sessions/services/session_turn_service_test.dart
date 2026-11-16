import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/features/permissions/media_control.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/services/session_commands.dart';
import 'package:totem_core/features/sessions/services/session_turn_service.dart';

RoomState _room({
  int version = 10,
  String speaker = 'participant',
  String next = 'other',
}) => RoomState(
  sessionSlug: 'session',
  version: version,
  status: RoomStatus.active,
  turnState: TurnState.idle,
  statusDetail: const RoomStateStatusDetailActive(ActiveDetail()),
  talkingOrder: const ['participant', 'other'],
  keeper: 'keeper',
  roundNumber: 1,
  currentSpeaker: Omittable(speaker),
  nextSpeaker: Omittable(next),
);

class _Backend implements SessionTurnBackend {
  _Backend(this.perform);
  final Future<RoomState> Function(String command, int version) perform;

  @override
  Future<RoomState> pass(
    int version, {
    String? customPrompt,
    int? sessionPromptId,
  }) => perform('pass', version);
  @override
  Future<RoomState> accept(int version) => perform('accept', version);
  @override
  Future<RoomState> reorder(int version, List<String> order) =>
      perform('reorder', version);
  @override
  Future<RoomState> forcePass(int version) => perform('forcePass', version);
  @override
  Future<RoomState> start(int version, {String? prompt}) =>
      perform('start', version);
  @override
  Future<RoomState> end(int version) => perform('end', version);
  @override
  Future<RoomState> setPrompt(
    int version, {
    String? customPrompt,
    int? sessionPromptId,
    bool clearPrompt = false,
  }) => perform('prompt', version);
}

class _Harness {
  _Harness({bool accepting = false}) {
    room = accepting ? _room(speaker: 'other', next: 'participant') : _room();
    response = accepting
        ? _room(version: 11)
        : _room(version: 11, speaker: 'other');
    service = SessionTurnService(
      backend: _Backend((command, version) async {
        requests.add((command, version));
        effects.add('backend:$command');
        return await perform?.call(command, version) ?? response;
      }),
      state: () => SessionRoomState(
        connection: const ConnectionState(
          phase: SessionPhase.connected,
          state: RoomConnectionState.connected,
        ),
        participants: ParticipantsState(
          participants: keeperPresent
              ? const [
                  ParticipantInfo(
                    sid: 'keeper',
                    identity: 'keeper',
                    name: 'Keeper',
                  ),
                ]
              : const [],
        ),
        turn: SessionTurnState(roomState: room),
      ),
      localIdentity: () => 'participant',
      isKeeper: () => keeper,
      applyState: (next) {
        effects.add('commit');
        commits.add(next);
        room = next;
      },
      disableMicrophone: () async {
        effects.add('disable');
        await mute?.call();
        if (muteApplies) microphoneOn = false;
      },
      enableMicrophone: () async {
        effects.add('enable');
        return await capture?.call() ?? const TurnedOn();
      },
      microphoneRevision: () => revision,
      microphoneDesired: () => desired,
      microphoneEnabled: () => microphoneOn,
      flagMicrophoneProblem: () {
        effects.add('attention');
        attention++;
      },
      captureValidity: () {
        final attempt = generation;
        return () => attempt == generation;
      },
    );
  }

  late final SessionTurnService service;
  late RoomState room;
  late RoomState response;
  Future<RoomState> Function(String, int)? perform;
  Future<TurnOnOutcome> Function()? capture;
  Future<void> Function()? mute;
  bool muteApplies = true;
  final requests = <(String, int)>[];
  final effects = <String>[];
  final commits = <RoomState>[];
  bool microphoneOn = true;
  bool desired = true;
  bool keeper = false;
  bool keeperPresent = true;
  int revision = 0;
  int generation = 0;
  int attention = 0;
}

void main() {
  test(
    'a network failure preserves the speaking turn and microphone, then permits a successful retry',
    () async {
      final h = _Harness();
      addTearDown(h.service.dispose);
      final previous = h.room;
      final failure = AppNetworkException.noConnection();
      h.perform = (_, _) async => throw failure;

      await check(h.service.passTotem()).throws<AppNetworkException>();

      check(h.room).identicalTo(previous);
      check(h.microphoneOn).isTrue();
      check(h.commits).isEmpty();
      check(h.effects).deepEquals(['backend:pass']);
      check(
        h.service.lastFailure?.kind,
      ).equals(SessionCommandFailureKind.network);
      check(h.service.lastFailure?.error).identicalTo(failure);

      h.perform = null;
      await h.service.passTotem();
      check(h.room.currentSpeaker.value).equals('other');
      check(h.microphoneOn).isFalse();
      check(h.service.lastFailure).isNull();
    },
  );

  test('backend rejection preserves the current turn and microphone', () async {
    final h = _Harness();
    addTearDown(h.service.dispose);
    final previous = h.room;
    const rejection = ApiError<RoomState, RoomErrorResponse>(
      statusCode: 409,
      error: RoomErrorResponse(
        code: ErrorCode.notCurrentSpeaker,
        message: 'The speaking turn has changed',
      ),
    );
    h.perform = (_, _) async => throw rejection;

    await check(
      h.service.passTotem(),
    ).throws<ApiError<RoomState, RoomErrorResponse>>();

    check(h.room).identicalTo(previous);
    check(h.microphoneOn).isTrue();
    check(h.commits).isEmpty();
    check(h.effects).deepEquals(['backend:pass']);
    check(h.service.lastFailure?.error).identicalTo(rejection);
  });

  for (final committed in [false, true]) {
    for (final reenabled in [false, true]) {
      test(
        'pending pass respects manual microphone decisions (committed: $committed, reenabled: $reenabled)',
        () async {
          final h = _Harness();
          addTearDown(h.service.dispose);
          final previous = h.room;
          final started = Completer<void>();
          final response = Completer<RoomState>();
          h.perform = (_, _) {
            started.complete();
            return response.future;
          };
          final passing = h.service.passTotem();
          final rejected = committed
              ? null
              : check(passing).throws<AppNetworkException>();
          await started.future;
          h
            ..microphoneOn = false
            ..desired = false
            ..revision = h.revision + 1;
          if (reenabled) {
            h
              ..microphoneOn = true
              ..desired = true
              ..revision = h.revision + 1;
          }
          if (committed) {
            response.complete(h.response);
            await passing;
            check(h.room.currentSpeaker.value).equals('other');
            check(h.commits.single).identicalTo(h.response);
            check(h.microphoneOn).isFalse();
            check(h.effects).deepEquals(['backend:pass', 'commit', 'disable']);
          } else {
            response.completeError(AppNetworkException.noConnection());
            await rejected;
            check(h.room).identicalTo(previous);
            check(h.commits).isEmpty();
            check(h.microphoneOn).equals(reenabled);
            check(h.effects).deepEquals(['backend:pass']);
          }
        },
      );
    }
  }

  test(
    'a successful pass commits server state before muting the former speaker',
    () async {
      final h = _Harness();
      addTearDown(h.service.dispose);
      final gate = Completer<RoomState>();
      final started = Completer<void>();
      h.perform = (_, _) {
        started.complete();
        return gate.future;
      };
      final passing = h.service.passTotem();
      await started.future;

      check(h.microphoneOn).isTrue();
      check(h.commits).isEmpty();
      check(h.requests).deepEquals([('pass', 10)]);
      gate.complete(h.response);
      await passing;

      check(h.effects).deepEquals(['backend:pass', 'commit', 'disable']);
      check(h.commits.single).identicalTo(h.response);
      check(h.microphoneOn).isFalse();
    },
  );

  for (final throws in [false, true]) {
    test(
      'committed pass reports partial success if the microphone cannot mute (throws: $throws)',
      () async {
        final h = _Harness();
        addTearDown(h.service.dispose);
        if (throws) {
          h.mute = () async => throw StateError('device release failed');
        } else {
          h.muteApplies = false;
        }
        await check(h.service.passTotem()).throws<SessionCommandException>();
        check(h.room.currentSpeaker.value).equals('other');
        check(h.commits.single).identicalTo(h.response);
        check(h.microphoneOn).isTrue();
        check(
          h.service.lastFailure?.kind,
        ).equals(SessionCommandFailureKind.partialSuccess);
        check(h.requests).deepEquals([('pass', 10)]);
      },
    );
  }

  test(
    'a committed pass that keeps the local participant speaking does not mute them',
    () async {
      final h = _Harness()..response = _room(version: 11);
      addTearDown(h.service.dispose);

      await h.service.passTotem();

      check(h.effects).deepEquals(['backend:pass', 'commit']);
      check(h.microphoneOn).isTrue();
    },
  );

  test(
    'an unchanged pass response cannot report a committed transition',
    () async {
      final h = _Harness();
      addTearDown(h.service.dispose);
      final previous = h.room;
      h.response = previous;

      await check(h.service.passTotem()).throws<SessionCommandException>();

      check(h.room).identicalTo(previous);
      check(h.commits).isEmpty();
      check(h.microphoneOn).isTrue();
      check(h.effects).deepEquals(['backend:pass']);
      check(
        h.service.lastFailure?.kind,
      ).equals(SessionCommandFailureKind.conflict);
    },
  );

  test(
    'overlapping turn commands are refused without duplicating backend or media work',
    () async {
      final h = _Harness();
      addTearDown(h.service.dispose);
      final gate = Completer<RoomState>();
      final started = Completer<void>();
      h.perform = (_, _) {
        started.complete();
        return gate.future;
      };
      final passing = h.service.passTotem();
      await started.future;

      await check(h.service.passTotem()).throws<SessionCommandException>();
      check(h.requests).deepEquals([('pass', 10)]);
      check(h.microphoneOn).isTrue();
      gate.complete(h.response);
      await passing;
      check(h.effects).deepEquals(['backend:pass', 'commit', 'disable']);
    },
  );

  for (final acceptedVersion in [11, 20]) {
    test(
      'a conflicting response cannot replace an accepted room version $acceptedVersion or change media',
      () async {
        final h = _Harness();
        addTearDown(h.service.dispose);
        final gate = Completer<RoomState>();
        final started = Completer<void>();
        h.perform = (_, _) {
          started.complete();
          return gate.future;
        };
        final passing = h.service.passTotem();
        final rejected = check(passing).throws<SessionCommandException>();
        await started.future;
        final accepted = _room(version: acceptedVersion);
        h.room = accepted;
        gate.complete(h.response);
        await rejected;

        check(h.room).identicalTo(accepted);
        check(h.commits).isEmpty();
        check(h.microphoneOn).isTrue();
        check(
          h.service.lastFailure?.kind,
        ).equals(SessionCommandFailureKind.conflict);
      },
    );
  }

  test(
    'an identical room update observed before the pass response still completes the pass',
    () async {
      final h = _Harness();
      addTearDown(h.service.dispose);
      final started = Completer<void>();
      final response = Completer<RoomState>();
      h.perform = (_, _) {
        started.complete();
        return response.future;
      };
      final passing = h.service.passTotem();
      await started.future;
      final observed = _room(version: 11, speaker: 'other');
      h.room = observed;
      response.complete(h.response);
      await passing;

      check(h.room).equals(observed);
      check(h.microphoneOn).isFalse();
      check(h.requests).deepEquals([('pass', 10)]);
      check(h.service.lastFailure).isNull();
    },
  );

  test(
    'the existing equal-version session-ending transition remains accepted',
    () async {
      final h = _Harness()..keeper = true;
      addTearDown(h.service.dispose);
      h.response = h.room.copyWith(
        status: RoomStatus.ended,
        statusDetail: const RoomStateStatusDetailEnded(
          EndedDetail(reason: EndReason.keeperEnded),
        ),
      );

      await h.service.end();

      check(h.room.status).equals(RoomStatus.ended);
      check(h.room.version).equals(10);
      check(h.commits.single).identicalTo(h.response);
      check(h.effects).deepEquals(['backend:end', 'commit']);
      check(h.service.lastFailure).isNull();
    },
  );

  for (final disposed in [false, true]) {
    test(
      'a pending command cannot affect an ended attempt (disposed: $disposed)',
      () async {
        final h = _Harness();
        addTearDown(h.service.dispose);
        final gate = Completer<RoomState>();
        final started = Completer<void>();
        h.perform = (_, _) {
          started.complete();
          return gate.future;
        };
        final passing = h.service.passTotem();
        final rejected = check(passing).throws<SessionCommandException>();
        await started.future;
        if (disposed) {
          h.service.dispose();
        } else {
          h.generation++;
        }
        gate.complete(h.response);
        await rejected;

        check(h.commits).isEmpty();
        check(h.microphoneOn).isTrue();
        check(
          h.service.lastFailure?.kind,
        ).equals(SessionCommandFailureKind.superseded);
      },
    );
  }

  test(
    'acceptance rejection never starts capture or changes the next speaker',
    () async {
      final h = _Harness(accepting: true);
      addTearDown(h.service.dispose);
      final previous = h.room;
      h.perform = (_, _) async => throw AppNetworkException.timeout();

      await check(h.service.acceptTotem()).throws<AppNetworkException>();

      check(h.effects).deepEquals(['backend:accept']);
      check(h.room).identicalTo(previous);
      check(h.commits).isEmpty();
      check(h.attention).equals(0);
      check(
        h.service.lastFailure?.kind,
      ).equals(SessionCommandFailureKind.network);
    },
  );

  test(
    'accepted turn survives a capture failure and reports device attention separately',
    () async {
      final h = _Harness(accepting: true);
      addTearDown(h.service.dispose);
      h.capture = () async =>
          const TurnOnFailed(DeviceFailed(DeviceProblem.notFound));

      check(
        await h.service.acceptTotem(),
      ).equals(TurnAcceptance.acceptedDeviceUnavailable);

      check(h.room.currentSpeaker.value).equals('participant');
      check(h.room.version).equals(11);
      check(h.commits.single).identicalTo(h.response);
      check(
        h.effects,
      ).deepEquals(['backend:accept', 'commit', 'enable', 'attention']);
      check(h.attention).equals(1);
    },
  );

  test('unexpected capture error cannot undo an accepted turn', () async {
    final h = _Harness(accepting: true);
    addTearDown(h.service.dispose);
    h.capture = () async =>
        throw StateError('capture failed outside normal recovery');
    check(
      await h.service.acceptTotem(),
    ).equals(TurnAcceptance.acceptedDeviceUnavailable);
    check(h.room.currentSpeaker.value).equals('participant');
    check(h.commits.single).identicalTo(h.response);
    check(h.attention).equals(1);
    check(
      h.effects,
    ).deepEquals(['backend:accept', 'commit', 'enable', 'attention']);
  });

  for (final preferenceChanged in [false, true]) {
    test(
      'accepted turn respects a microphone kept off during the request (new decision: $preferenceChanged)',
      () async {
        final h = _Harness(accepting: true);
        addTearDown(h.service.dispose);
        if (!preferenceChanged) h.desired = false;
        final gate = Completer<RoomState>();
        final started = Completer<void>();
        h.perform = (_, _) {
          started.complete();
          return gate.future;
        };
        final accepting = h.service.acceptTotem();
        await started.future;
        if (preferenceChanged) {
          h.revision++;
          h.desired = false;
        }
        gate.complete(h.response);

        check(await accepting).equals(TurnAcceptance.accepted);
        check(h.room.currentSpeaker.value).equals('participant');
        check(h.effects).deepEquals(['backend:accept', 'commit']);
        check(h.attention).equals(0);
      },
    );
  }

  test(
    'a changed microphone revision does not recapture even if the user enabled it again',
    () async {
      final h = _Harness(accepting: true);
      addTearDown(h.service.dispose);
      final gate = Completer<RoomState>();
      final started = Completer<void>();
      h.perform = (_, _) {
        started.complete();
        return gate.future;
      };
      final accepting = h.service.acceptTotem();
      await started.future;
      h.revision += 2;
      gate.complete(h.response);

      check(await accepting).equals(TurnAcceptance.accepted);
      check(h.effects).deepEquals(['backend:accept', 'commit']);
    },
  );

  test(
    'healthy microphone capture follows successful turn acceptance without attention',
    () async {
      final h = _Harness(accepting: true);
      addTearDown(h.service.dispose);

      check(await h.service.acceptTotem()).equals(TurnAcceptance.accepted);

      check(h.effects).deepEquals(['backend:accept', 'commit', 'enable']);
      check(h.room.currentSpeaker.value).equals('participant');
      check(h.attention).equals(0);
    },
  );

  test(
    'capture failure finishing after the attempt ends cannot notify the next session',
    () async {
      final h = _Harness(accepting: true);
      addTearDown(h.service.dispose);
      final captureStarted = Completer<void>();
      final capture = Completer<TurnOnOutcome>();
      h.capture = () {
        captureStarted.complete();
        return capture.future;
      };
      final accepting = h.service.acceptTotem();
      await captureStarted.future;
      h.generation++;
      capture.complete(
        const TurnOnFailed(PermissionRefused(MediaPermission.blocked)),
      );

      check(await accepting).equals(TurnAcceptance.accepted);
      check(h.attention).equals(0);
      check(h.effects).deepEquals(['backend:accept', 'commit', 'enable']);
    },
  );

  test(
    'Keeper-only commands reject participants without a backend mutation',
    () async {
      final h = _Harness();
      addTearDown(h.service.dispose);

      await check(h.service.start()).throws<SessionCommandException>();
      await check(h.service.end()).throws<SessionCommandException>();
      await check(
        h.service.reorder(['other', 'participant']),
      ).throws<SessionCommandException>();
      await check(
        h.service.setPrompt(customPrompt: 'A new round'),
      ).throws<SessionCommandException>();

      check(h.requests).isEmpty();
      check(h.effects).isEmpty();
      check(
        h.service.lastFailure?.kind,
      ).equals(SessionCommandFailureKind.unauthorized);
    },
  );

  test(
    'passing without a Keeper refuses the transition and leaves the microphone alone',
    () async {
      final h = _Harness()..keeperPresent = false;
      addTearDown(h.service.dispose);

      await check(h.service.passTotem()).throws<SessionCommandException>();

      check(h.requests).isEmpty();
      check(h.microphoneOn).isTrue();
      check(
        h.service.lastFailure?.kind,
      ).equals(SessionCommandFailureKind.invalidState);
    },
  );
}
