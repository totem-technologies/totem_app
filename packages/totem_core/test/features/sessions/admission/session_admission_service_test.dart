import 'dart:async';
import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/declined_session_participants.dart';
import 'package:totem_core/features/sessions/admission/keeper_admission_roster.dart';
import 'package:totem_core/features/sessions/admission/session_admission_service.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart'
    as state;
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

import '../../../setup.dart';
import '../session_test_mocks.dart';

class _Session extends Mock implements SessionController {}

class _Transport extends Mock implements SessionTransport {}

class _Preferences extends Fake implements SessionAdmissionPreferences {
  final values = <String, String>{};
  Future<bool> Function(String key, String value)? beforeSet;

  @override
  String? getString(String key) => values[key];
  @override
  Future<bool> setString(String key, String value) async {
    if (!await (beforeSet?.call(key, value) ?? Future.value(true))) {
      return false;
    }
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }
}

const _journalRosterKey = 'session_admission_keeper_roster:journal-test:keeper';
final _journalKey =
    'session_admission_revocations:${jsonEncode(['journal-test', 'keeper'])}';

({
  ProviderContainer owner,
  SessionAdmissionService service,
  List<AdmissionPacket> sent,
})
_journalService(_Preferences preferences, DateTime Function() now) {
  final session = _Session();
  final transport = _Transport();
  final roomState = MockSessionRoomState();
  final sent = <AdmissionPacket>[];
  when(() => transport.localIdentity).thenReturn('keeper');
  when(() => transport.metadata).thenReturn(null);
  when(() => transport.participants).thenReturn(const [
    ParticipantInfo(sid: 'a', identity: 'alice', name: 'Alice'),
    ParticipantInfo(sid: 'g', identity: 'guest', name: 'Guest'),
    ParticipantInfo(sid: 'b', identity: 'bob', name: 'Bob'),
  ]);
  when(
    () => transport.connectionState,
  ).thenReturn(SessionTransportConnectionState.connected);
  when(() => transport.publish(any())).thenAnswer((call) async {
    final packet = call.positionalArguments.single as SessionTransportPacket;
    final decoded = AdmissionProtocol.decode(
      packet.bytes,
      senderIdentity: 'keeper',
      now: now(),
    );
    if (decoded != null) sent.add(decoded);
  });
  when(() => session.transport).thenReturn(transport);
  when(() => session.admissionState).thenReturn(roomState);
  when(() => session.session).thenReturn(null);
  when(() => session.options).thenReturn(
    const state.SessionOptions(
      sessionSlug: 'journal-test',
      token: '',
      cameraEnabled: false,
      microphoneEnabled: false,
      speakerEnabled: true,
      cameraOptions: SessionController.defaultCameraCaptureOptions,
    ),
  );
  when(() => session.updateAdmittedMediaRecipients(any())).thenReturn(null);
  when(() => roomState.connection).thenReturn(
    const state.ConnectionState(
      phase: state.SessionPhase.connected,
      state: state.RoomConnectionState.connected,
    ),
  );
  when(() => roomState.roomState).thenReturn(
    const RoomState(
      keeper: 'keeper',
      nextSpeaker: Omittable(''),
      currentSpeaker: Omittable(''),
      status: RoomStatus.active,
      turnState: TurnState.idle,
      sessionSlug: 'journal-test',
      statusDetail: RoomStateStatusDetailActive(ActiveDetail()),
      talkingOrder: [],
      version: 1,
      roundNumber: 1,
    ),
  );
  final provider = Provider<SessionAdmissionService>(
    (ref) => SessionAdmissionService(ref, session, now: now),
  );
  final owner = ProviderContainer(
    overrides: [
      sessionAdmissionPreferencesProvider.overrideWith(
        (ref) async => preferences,
      ),
    ],
  );
  return (owner: owner, service: owner.read(provider), sent: sent);
}

void main() {
  testWidgets(
    'keeper persists authority and grants before publishing and drains on close',
    (tester) async {
      setupAppConfig();
      registerFallbackValue(SessionTransportPacket(bytes: [], topic: ''));
      final session = _Session();
      final transport = _Transport();
      final roomState = MockSessionRoomState();
      final preferences = _Preferences();
      const guest = ParticipantInfo(sid: 'g', identity: 'guest', name: 'Guest');
      final sent = <AdmissionPacket>[];
      when(() => transport.localIdentity).thenReturn('keeper');
      when(() => transport.metadata).thenReturn(null);
      when(() => transport.participants).thenReturn([guest]);
      when(
        () => transport.connectionState,
      ).thenReturn(SessionTransportConnectionState.connected);
      when(() => transport.publish(any())).thenAnswer((call) async {
        final packet =
            call.positionalArguments.single as SessionTransportPacket;
        final decoded = AdmissionProtocol.decode(
          packet.bytes,
          senderIdentity: 'keeper',
          now: tester.binding.clock.now(),
        );
        if (decoded != null) sent.add(decoded);
      });
      when(() => session.transport).thenReturn(transport);
      when(() => session.admissionState).thenReturn(roomState);
      when(() => session.session).thenReturn(null);
      when(() => session.options).thenReturn(
        const state.SessionOptions(
          sessionSlug: 'keeper-test',
          token: '',
          cameraEnabled: false,
          microphoneEnabled: false,
          speakerEnabled: true,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
        ),
      );
      when(() => session.updateAdmittedMediaRecipients(any())).thenReturn(null);
      when(() => roomState.connection).thenReturn(
        const state.ConnectionState(
          phase: state.SessionPhase.connected,
          state: state.RoomConnectionState.connected,
        ),
      );
      when(() => roomState.roomState).thenReturn(
        const RoomState(
          keeper: 'keeper',
          nextSpeaker: Omittable(''),
          currentSpeaker: Omittable(''),
          status: RoomStatus.active,
          turnState: TurnState.idle,
          sessionSlug: 'keeper-test',
          statusDetail: RoomStateStatusDetailActive(ActiveDetail()),
          talkingOrder: [],
          version: 1,
          roundNumber: 1,
        ),
      );
      final initialWrite = Completer<bool>();
      preferences.beforeSet = (key, value) =>
          key.startsWith('session_admission_keeper_roster')
          ? initialWrite.future
          : Future.value(true);
      final provider = Provider<SessionAdmissionService>(
        (ref) => SessionAdmissionService(
          ref,
          session,
          now: tester.binding.clock.now,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          sessionAdmissionPreferencesProvider.overrideWith(
            (ref) async => preferences,
          ),
        ],
      );
      final service = container.read(provider)..sync();
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
      check(service.keeperController).isNull();
      check(sent.whereType<AdmissionHello>()).isEmpty();
      initialWrite.complete(true);
      preferences.beforeSet = null;
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
      var controller = service.keeperController!;
      final rosterKey = preferences.values.keys.singleWhere(
        (key) => key.startsWith('session_admission_keeper_roster'),
      );
      final stored =
          jsonDecode(preferences.values[rosterKey]!) as Map<String, dynamic>;
      check(stored['generation']).equals(controller.keeperGeneration);
      final expiry = tester.binding.clock.now().add(const Duration(minutes: 1));
      void receive(AdmissionPacket packet) => service.handleTransportEvent(
        TransportPacketReceived(
          SessionTransportPacket(
            bytes: AdmissionProtocol.encode(packet),
            topic: AdmissionProtocol.topic,
            sender: guest,
          ),
        ),
      );
      final request = AdmissionRequest(
        id: 'request',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: expiry,
        displayName: 'Guest',
      );
      receive(request);
      await tester.pump();
      final decision = service.decide(request, true);
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      await decision;
      final grantWrite = Completer<bool>();
      preferences.beforeSet = (key, value) =>
          key == rosterKey ? grantWrite.future : Future.value(true);
      receive(
        AdmissionJoined(
          id: 'request',
          senderIdentity: 'guest',
          recipientIdentity: 'keeper',
          expiresAt: expiry,
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      check(service.admittedIdentities).isEmpty();
      check(
        sent.whereType<AdmissionRosterUpdated>().where(
          (p) => p.members.contains('guest'),
        ),
      ).isEmpty();
      grantWrite.complete(false);
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
      check(controller.persistenceError).isNotNull();
      check(service.admittedIdentities).isEmpty();
      preferences.beforeSet = null;
      final retry = service.retryRecovery();
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
      await retry;
      check(service.admittedIdentities).deepEquals({'guest'});
      final generation = controller.keeperGeneration;
      var disconnected = false;
      final disconnecting = service.disconnect().then(
        (_) => disconnected = true,
      );
      for (var i = 0; i < 20 && !disconnected; i++) {
        await tester.runAsync(() async {});
        await tester.pump();
      }
      check(disconnected).isTrue();
      await disconnecting;
      service.sync();
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
      controller = service.keeperController!;
      check(controller.keeperGeneration).equals(generation);
      check(service.admittedIdentities).deepEquals({'guest'});
      final revokeWrite = Completer<bool>();
      preferences.beforeSet = (key, value) =>
          key == rosterKey ? revokeWrite.future : Future.value(true);
      controller.revoke('guest');
      await tester.pump();
      check(controller.roster).isEmpty();
      var closed = false;
      final closing = service.close().then((_) => closed = true);
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      check(closed).isFalse();
      preferences.beforeSet = null;
      revokeWrite.complete(true);
      for (var i = 0; i < 20 && !closed; i++) {
        await tester.runAsync(() async {});
        await tester.pump();
      }
      check(closed).isTrue();
      await closing;
      container.dispose();
    },
  );

  testWidgets(
    'journaled revocation publishes before roster save and survives restart',
    (tester) async {
      setupAppConfig();
      registerFallbackValue(SessionTransportPacket(bytes: [], topic: ''));
      final session = _Session();
      final transport = _Transport();
      final roomState = MockSessionRoomState();
      final preferences = _Preferences();
      const rosterKey = 'session_admission_keeper_roster:journal-test:keeper';
      final journalKey =
          'session_admission_revocations:${jsonEncode(['journal-test', 'keeper'])}';
      preferences.values[rosterKey] = jsonEncode({
        'version': 1,
        'generation': 'original-generation',
        'revision': 7,
        'members': ['alice', 'bob', 'guest'],
        'awaitingReadiness': ['bob'],
        'revoked': <String>[],
      });
      const alice = ParticipantInfo(sid: 'a', identity: 'alice', name: 'Alice');
      const guest = ParticipantInfo(sid: 'g', identity: 'guest', name: 'Guest');
      final sent = <AdmissionPacket>[];
      when(() => transport.localIdentity).thenReturn('keeper');
      when(() => transport.metadata).thenReturn(null);
      when(() => transport.participants).thenReturn([alice, guest]);
      when(
        () => transport.connectionState,
      ).thenReturn(SessionTransportConnectionState.connected);
      when(() => transport.publish(any())).thenAnswer((call) async {
        final packet =
            call.positionalArguments.single as SessionTransportPacket;
        final decoded = AdmissionProtocol.decode(
          packet.bytes,
          senderIdentity: 'keeper',
          now: tester.binding.clock.now(),
        );
        if (decoded != null) sent.add(decoded);
      });
      when(() => session.transport).thenReturn(transport);
      when(() => session.admissionState).thenReturn(roomState);
      when(() => session.session).thenReturn(null);
      when(() => session.options).thenReturn(
        const state.SessionOptions(
          sessionSlug: 'journal-test',
          token: '',
          cameraEnabled: false,
          microphoneEnabled: false,
          speakerEnabled: true,
          cameraOptions: SessionController.defaultCameraCaptureOptions,
        ),
      );
      when(() => session.updateAdmittedMediaRecipients(any())).thenReturn(null);
      when(() => roomState.connection).thenReturn(
        const state.ConnectionState(
          phase: state.SessionPhase.connected,
          state: state.RoomConnectionState.connected,
        ),
      );
      when(() => roomState.roomState).thenReturn(
        const RoomState(
          keeper: 'keeper',
          nextSpeaker: Omittable(''),
          currentSpeaker: Omittable(''),
          status: RoomStatus.active,
          turnState: TurnState.idle,
          sessionSlug: 'journal-test',
          statusDetail: RoomStateStatusDetailActive(ActiveDetail()),
          talkingOrder: [],
          version: 1,
          roundNumber: 1,
        ),
      );
      final provider = Provider<SessionAdmissionService>(
        (ref) => SessionAdmissionService(
          ref,
          session,
          now: tester.binding.clock.now,
        ),
      );
      ProviderContainer container() => ProviderContainer(
        overrides: [
          sessionAdmissionPreferencesProvider.overrideWith(
            (ref) async => preferences,
          ),
        ],
      );
      var owner = container();
      var service = owner.read(provider)..sync();
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
      check(service.admittedIdentities).deepEquals({'alice', 'guest'});
      final removal = await service.prepareRemoval('guest');
      final rosterWrite = Completer<bool>();
      final writeStarted = Completer<void>();
      preferences.beforeSet = (key, value) {
        if (key == rosterKey) {
          if (!writeStarted.isCompleted) writeStarted.complete();
          return rosterWrite.future;
        }
        return Future.value(true);
      };
      sent.clear();
      final committed = removal.commit();
      final failedCommit = check(committed).throws<StateError>();
      for (var i = 0; i < 10 && !writeStarted.isCompleted; i++) {
        await tester.pump();
      }
      check(writeStarted.isCompleted).isTrue();
      check(service.admittedIdentities).deepEquals({'alice'});
      final envelope =
          jsonDecode(preferences.values[journalKey]!) as Map<String, dynamic>;
      final snapshot = envelope['roster'] as Map<String, dynamic>;
      check(envelope['version']).equals(1);
      check(
        envelope['records'] as Map<String, dynamic>,
      ).deepEquals({'guest': 'committed'});
      check(snapshot).deepEquals({
        'generation': 'original-generation',
        'revision': 8,
        'members': ['alice', 'bob'],
        'awaitingReadiness': ['bob'],
        'revoked': ['guest'],
      });
      check(
        (jsonDecode(preferences.values[rosterKey]!)
            as Map<String, dynamic>)['revision'],
      ).equals(7);
      final updates = sent.whereType<AdmissionRosterUpdated>().toList();
      check(
        updates.any(
          (packet) =>
              packet.keeperGeneration == snapshot['generation'] &&
              packet.revision == snapshot['revision'] &&
              !packet.members.contains('guest'),
        ),
      ).isTrue();
      rosterWrite.complete(false);
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
      await failedCommit;
      check(
        jsonDecode(preferences.values[journalKey]!) as Map<String, dynamic>,
      ).deepEquals(envelope);
      var closed = false;
      final closing = check(
        service.close(),
      ).throws<StateError>().then((_) => closed = true);
      for (var i = 0; i < 20 && !closed; i++) {
        await tester.runAsync(() async {});
        await tester.pump();
      }
      check(closed).isTrue();
      await closing;
      owner.dispose();

      final recoveryWrite = Completer<bool>();
      final recoveryStarted = Completer<void>();
      preferences.beforeSet = (key, value) {
        if (key == rosterKey) {
          if (!recoveryStarted.isCompleted) recoveryStarted.complete();
          return recoveryWrite.future;
        }
        return Future.value(true);
      };
      sent.clear();
      owner = container();
      service = owner.read(provider)..sync();
      for (var i = 0; i < 10 && !recoveryStarted.isCompleted; i++) {
        await tester.pump();
      }
      check(recoveryStarted.isCompleted).isTrue();
      check(sent.whereType<AdmissionHello>()).isEmpty();
      check(sent.whereType<AdmissionRosterUpdated>()).isEmpty();
      preferences.beforeSet = null;
      recoveryWrite.complete(true);
      for (var i = 0; i < 15; i++) {
        await tester.pump();
      }
      final controller = service.keeperController!;
      check(
        controller.keeperGeneration,
      ).equals(snapshot['generation'] as String);
      check(controller.roster).deepEquals(['alice']);
      final persisted =
          jsonDecode(preferences.values[rosterKey]!) as Map<String, dynamic>;
      check(persisted['generation']).equals(snapshot['generation']);
      check(persisted['revision']).equals(snapshot['revision']);
      check(
        persisted['members'] as List<dynamic>,
      ).deepEquals(snapshot['members'] as List<dynamic>);
      check(
        persisted['awaitingReadiness'] as List<dynamic>,
      ).deepEquals(snapshot['awaitingReadiness'] as List<dynamic>);
      check(
        persisted['revoked'] as List<dynamic>,
      ).deepEquals(snapshot['revoked'] as List<dynamic>);
      check(preferences.values.containsKey(journalKey)).isFalse();
      closed = false;
      final finalClose = service.close().then((_) => closed = true);
      for (var i = 0; i < 20 && !closed; i++) {
        await tester.runAsync(() async {});
        await tester.pump();
      }
      check(closed).isTrue();
      await finalClose;
      owner.dispose();
    },
  );

  testWidgets('detached reconciliation preserves newer journal restrictions', (
    tester,
  ) async {
    setupAppConfig();
    registerFallbackValue(SessionTransportPacket(bytes: [], topic: ''));
    final preferences = _Preferences();
    preferences.values[_journalRosterKey] = jsonEncode({
      'version': 1,
      'generation': 'generation',
      'revision': 7,
      'members': ['alice', 'bob', 'guest'],
      'awaitingReadiness': <String>[],
      'revoked': <String>[],
    });
    preferences.values[_journalKey] = jsonEncode({
      'version': 1,
      'records': {'guest': 'committed', 'bob': 'intent'},
      'roster': {
        'generation': 'generation',
        'revision': 8,
        'members': ['alice', 'bob'],
        'awaitingReadiness': <String>[],
        'revoked': ['guest'],
      },
    });
    preferences.beforeSet = (key, _) async => key != _journalRosterKey;
    final harness = _journalService(preferences, tester.binding.clock.now);
    harness.service.sync();
    for (var i = 0; i < 15; i++) {
      await tester.pump();
    }
    check(harness.service.keeperController).isNull();
    check(harness.service.unresolvedRemovals).deepEquals({'bob'});
    check(
      (jsonDecode(preferences.values[_journalRosterKey]!)
          as Map<String, dynamic>)['revision'],
    ).equals(7);
    harness.owner.invalidate(
      keeperAdmissionRosterProvider('journal-test', 'keeper'),
    );
    preferences.beforeSet = null;
    final reconciliation = harness.service.reconcileRemoval(
      'bob',
      backendRemoved: true,
    );
    for (var i = 0; i < 15; i++) {
      await tester.pump();
    }
    await reconciliation;
    final saved =
        jsonDecode(preferences.values[_journalRosterKey]!)
            as Map<String, dynamic>;
    check(saved['generation']).equals('generation');
    check(saved['revision']).equals(9);
    check(saved['members'] as List<dynamic>).deepEquals(['alice']);
    check(saved['revoked'] as List<dynamic>).deepEquals(['bob', 'guest']);
    harness.service.sync();
    for (var i = 0; i < 15; i++) {
      await tester.pump();
    }
    check(harness.service.admittedIdentities).deepEquals({'alice'});
    check(
      harness.sent.whereType<AdmissionRosterUpdated>().where(
        (p) => p.members.contains('guest') || p.members.contains('bob'),
      ),
    ).isEmpty();
    var closed = false;
    final closing = harness.service
        .close()
        .catchError((Object _) {})
        .then((_) => closed = true);
    for (var i = 0; i < 20 && !closed; i++) {
      await tester.runAsync(() async {});
      await tester.pump();
    }
    check(closed).isTrue();
    await closing;
    harness.owner.dispose();
  });

  testWidgets(
    'restart after full commit advertises the durable restricted roster',
    (tester) async {
      setupAppConfig();
      registerFallbackValue(SessionTransportPacket(bytes: [], topic: ''));
      final preferences = _Preferences();
      final snapshot = {
        'generation': 'generation',
        'revision': 8,
        'members': ['alice', 'bob'],
        'awaitingReadiness': ['bob'],
        'revoked': ['guest'],
      };
      preferences.values[_journalRosterKey] = jsonEncode({
        'version': 1,
        ...snapshot,
      });
      preferences.values[_journalKey] = jsonEncode({
        'version': 1,
        'records': {'guest': 'committed'},
        'roster': snapshot,
      });
      final harness = _journalService(preferences, tester.binding.clock.now);
      harness.service.sync();
      for (var i = 0; i < 15; i++) {
        await tester.pump();
      }
      final controller = harness.service.keeperController!;
      check(controller.keeperGeneration).equals('generation');
      check(controller.rosterRevision).equals(8);
      check(harness.service.admittedIdentities).deepEquals({'alice'});
      final saved =
          jsonDecode(preferences.values[_journalRosterKey]!)
              as Map<String, dynamic>;
      check(saved).deepEquals({'version': 1, ...snapshot});
      check(preferences.values.containsKey(_journalKey)).isFalse();
      check(
        harness.sent.whereType<AdmissionRosterUpdated>().where(
          (p) => p.members.contains('guest'),
        ),
      ).isEmpty();
      check(harness.sent.whereType<AdmissionHello>().isNotEmpty).isTrue();
      var closed = false;
      final closing = harness.service.close().then((_) => closed = true);
      for (var i = 0; i < 20 && !closed; i++) {
        await tester.runAsync(() async {});
        await tester.pump();
      }
      check(closed).isTrue();
      await closing;
      harness.owner.dispose();
    },
  );

  testWidgets(
    'started unban reservation remains guarded through service handoff',
    (tester) async {
      setupAppConfig();
      registerFallbackValue(SessionTransportPacket(bytes: [], topic: ''));
      final preferences = _Preferences();
      Future<void> close(
        ({
          ProviderContainer owner,
          SessionAdmissionService service,
          List<AdmissionPacket> sent,
        })
        harness,
      ) async {
        var closed = false;
        final closing = harness.service.close().then((_) => closed = true);
        for (var i = 0; i < 20 && !closed; i++) {
          await tester.runAsync(() async {});
          await tester.pump();
        }
        check(closed).isTrue();
        await closing;
        harness.owner.dispose();
      }

      final first = _journalService(preferences, tester.binding.clock.now);
      first.service.sync();
      for (var i = 0; i < 15; i++) {
        await tester.pump();
      }
      final backend = Completer<void>();
      final reservation = await first.service.reserveUnban('guest');
      final unbanning = reservation.run(() => backend.future);
      await tester.pump();

      await close(first);

      final second = _journalService(preferences, tester.binding.clock.now);
      second.service.sync();
      for (var i = 0; i < 15; i++) {
        await tester.pump();
      }
      await check(second.service.reserveUnban('guest')).throws<StateError>();

      backend.complete();
      await unbanning;
      final replacement = await second.service.reserveUnban('guest');

      replacement.cancel();
      await close(second);
    },
  );

  testWidgets('recovery is bounded by fresh roster evidence', (tester) async {
    setupAppConfig();
    registerFallbackValue(SessionTransportPacket(bytes: [], topic: ''));
    final session = _Session();
    final transport = _Transport();
    final roomState = MockSessionRoomState();
    const keeper = ParticipantInfo(
      sid: 'k',
      identity: 'keeper',
      name: 'Keeper',
    );
    var keeperIdentity = 'keeper';
    var connectionState = state.RoomConnectionState.connected;
    final sent = <AdmissionPacket>[];
    when(() => transport.localIdentity).thenReturn('guest');
    when(() => transport.metadata).thenReturn(null);
    when(() => transport.participants).thenReturn([keeper]);
    when(
      () => transport.connectionState,
    ).thenReturn(SessionTransportConnectionState.connected);
    when(() => transport.publish(any())).thenAnswer((call) async {
      final packet = call.positionalArguments.single as SessionTransportPacket;
      final decoded = AdmissionProtocol.decode(
        packet.bytes,
        senderIdentity: 'guest',
        now: tester.binding.clock.now(),
      );
      if (decoded != null) sent.add(decoded);
    });
    when(() => session.transport).thenReturn(transport);
    when(() => session.admissionState).thenReturn(roomState);
    when(() => session.session).thenReturn(null);
    when(() => session.options).thenReturn(
      const state.SessionOptions(
        sessionSlug: 'session',
        token: '',
        cameraEnabled: false,
        microphoneEnabled: false,
        speakerEnabled: true,
        cameraOptions: SessionController.defaultCameraCaptureOptions,
      ),
    );
    when(() => session.updateAdmittedMediaRecipients(any())).thenReturn(null);
    when(() => roomState.connection).thenAnswer(
      (_) => state.ConnectionState(
        phase: state.SessionPhase.connected,
        state: connectionState,
      ),
    );
    when(() => roomState.roomState).thenAnswer(
      (_) => RoomState(
        keeper: keeperIdentity,
        nextSpeaker: const Omittable(''),
        currentSpeaker: const Omittable(''),
        status: RoomStatus.active,
        turnState: TurnState.idle,
        sessionSlug: 'session',
        statusDetail: const RoomStateStatusDetailActive(ActiveDetail()),
        talkingOrder: const [],
        version: 1,
        roundNumber: 1,
      ),
    );
    final provider = Provider<SessionAdmissionService>(
      (ref) => SessionAdmissionService(
        ref,
        session,
        now: tester.binding.clock.now,
        recoveryLease: const Duration(seconds: 90),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        sessionAdmissionPreferencesProvider.overrideWith(
          (ref) async => _Preferences(),
        ),
      ],
    );
    final service = container.read(provider)..sync();
    check(service.rosterTrust).equals(AdmissionRosterTrust.unverified);
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }

    final request = sent.whereType<AdmissionRosterRequest>().last;
    void receive(AdmissionPacket packet) => service.handleTransportEvent(
      TransportPacketReceived(
        SessionTransportPacket(
          bytes: AdmissionProtocol.encode(packet),
          topic: AdmissionProtocol.topic,
          sender: keeper,
        ),
      ),
    );
    void snapshot(
      String id,
      int revision,
      List<String> members,
      String requestId,
    ) => receive(
      AdmissionRosterSnapshot(
        id: id,
        senderIdentity: 'keeper',
        recipientIdentity: 'guest',
        expiresAt: tester.binding.clock.now().add(const Duration(minutes: 1)),
        sessionIdentity: 'session',
        keeperGeneration: 'generation',
        revision: revision,
        members: members,
        requestId: requestId,
      ),
    );
    snapshot('snapshot', 1, ['guest', 'alice'], request.id);
    await tester.pump();
    check(service.rosterTrust).equals(AdmissionRosterTrust.verified);
    check(service.admittedIdentities).deepEquals({'guest', 'alice'});

    service.handleTransportEvent(
      const TransportConnectionChanged(
        SessionTransportConnectionState.reconnecting,
      ),
    );
    await tester.pump();
    check(service.rosterTrust).equals(AdmissionRosterTrust.recovering);
    check(service.isSynchronizing).isTrue();
    check(service.admittedIdentities).deepEquals({'guest', 'alice'});
    final interruptedDeadline = service.recoveryDeadline;
    await tester.pump(const Duration(seconds: 1));
    check(service.admittedIdentities).deepEquals({'guest', 'alice'});
    await tester.pump(const Duration(seconds: 30));
    check(service.admittedIdentities).deepEquals({'guest', 'alice'});
    await tester.pump(const Duration(seconds: 6));
    snapshot('uncorrelated', 2, ['guest', 'alice', 'bob'], 'unknown-request');
    await tester.pump();
    check(service.recoveryDeadline).equals(interruptedDeadline);
    check(service.admittedIdentities).deepEquals({'guest', 'alice'});
    await tester.pump(const Duration(seconds: 53));
    check(service.rosterTrust).equals(AdmissionRosterTrust.expired);
    check(service.isSynchronizing).isTrue();
    check(service.admittedIdentities).isEmpty();
    check(identical(session.transport, transport)).isTrue();
    verifyNever(session.leave);
    verifyNever(session.disconnectFromRoom);
    verifyNever(transport.disconnect);
    verifyNever(transport.dispose);

    service.handleTransportEvent(
      const TransportConnectionChanged(
        SessionTransportConnectionState.connected,
        reconnected: true,
      ),
    );
    await tester.pump();
    final afterInterruption = sent.whereType<AdmissionRosterRequest>().last;
    snapshot('after-interruption', 1, ['guest', 'alice'], afterInterruption.id);
    await tester.pump();
    check(service.rosterTrust).equals(AdmissionRosterTrust.verified);
    var failures = 0;
    var supersedeFailure = false;
    when(() => transport.localIdentity).thenAnswer((_) {
      if (failures > 0) {
        failures--;
        if (supersedeFailure) service.sync();
        throw StateError('transient synchronization failure');
      }
      return 'guest';
    });
    failures = 1;
    service.sync();
    await tester.pump();
    check(failures).equals(0);
    check(service.rosterTrust).equals(AdmissionRosterTrust.recovering);
    check(service.isSynchronizing).isTrue();
    check(service.admittedIdentities).deepEquals({'guest', 'alice'});
    final deadline = service.recoveryDeadline;
    final retry = sent.whereType<AdmissionRosterRequest>().last;
    check(retry.id == request.id).isFalse();
    failures = 1;
    service.sync();
    await tester.pump();
    check(failures).equals(0);
    check(service.recoveryDeadline).equals(deadline);
    check(sent.whereType<AdmissionRosterRequest>().last.id).equals(retry.id);
    snapshot('retry', 1, ['guest', 'alice'], retry.id);
    await tester.pump();
    check(service.rosterTrust).equals(AdmissionRosterTrust.verified);
    service
      ..error = null
      ..recoveryError = null;
    supersedeFailure = true;
    failures = 1;
    service.sync();
    await tester.pump();
    check(failures).equals(0);
    check(service.rosterTrust).equals(AdmissionRosterTrust.verified);
    check(service.error).isNull();
    supersedeFailure = false;

    connectionState = state.RoomConnectionState.disconnected;
    service.sync();
    await tester.pump();
    check(service.rosterTrust).equals(AdmissionRosterTrust.recovering);
    check(service.admittedIdentities).deepEquals({'guest', 'alice'});
    connectionState = state.RoomConnectionState.connected;
    service
      ..sync()
      ..handleTransportEvent(
        const TransportParticipantChanged(keeper, present: false),
      );
    await tester.pump();
    check(service.rosterTrust).equals(AdmissionRosterTrust.recovering);
    await tester.pump(const Duration(seconds: 6));
    receive(
      AdmissionRosterUpdated(
        id: 'update',
        senderIdentity: 'keeper',
        recipientIdentity: 'guest',
        expiresAt: tester.binding.clock.now().add(const Duration(minutes: 1)),
        sessionIdentity: 'session',
        keeperGeneration: 'generation',
        revision: 2,
        members: const ['guest'],
      ),
    );
    await tester.pump();
    check(service.admittedIdentities).deepEquals({'guest'});
    await tester.pump(const Duration(seconds: 5));
    check(service.admittedIdentities).deepEquals({'guest'});
    receive(
      AdmissionRosterUpdated(
        id: 'stale',
        senderIdentity: 'keeper',
        recipientIdentity: 'guest',
        expiresAt: tester.binding.clock.now().add(const Duration(minutes: 1)),
        sessionIdentity: 'session',
        keeperGeneration: 'generation',
        revision: 2,
        members: const ['guest', 'alice'],
      ),
    );
    await tester.pump();
    final requestsBeforeExpiry = sent
        .whereType<AdmissionRosterRequest>()
        .length;
    await tester.pump(const Duration(seconds: 85));
    check(service.rosterTrust).equals(AdmissionRosterTrust.expired);
    check(service.isSynchronizing).isTrue();
    check(service.admittedIdentities).isEmpty();
    check(
      sent.whereType<AdmissionRosterRequest>().length > requestsBeforeExpiry,
    ).isTrue();
    receive(
      AdmissionRosterUpdated(
        id: 'fresh',
        senderIdentity: 'keeper',
        recipientIdentity: 'guest',
        expiresAt: tester.binding.clock.now().add(const Duration(minutes: 1)),
        sessionIdentity: 'session',
        keeperGeneration: 'generation',
        revision: 3,
        members: const ['guest', 'alice'],
      ),
    );
    await tester.pump();
    check(service.admittedIdentities).deepEquals({'guest', 'alice'});
    connectionState = state.RoomConnectionState.disconnected;
    service.sync();
    await tester.pump();
    await tester.pump(const Duration(seconds: 90));
    check(service.rosterTrust).equals(AdmissionRosterTrust.expired);
    check(service.admittedIdentities).isEmpty();
    connectionState = state.RoomConnectionState.connected;
    service
      ..sync()
      ..handleTransportEvent(
        const TransportConnectionChanged(
          SessionTransportConnectionState.connected,
          reconnected: true,
        ),
      );
    await tester.pump();
    final reconnect = sent.whereType<AdmissionRosterRequest>().last;
    snapshot('reconnected', 3, ['guest', 'alice'], reconnect.id);
    await tester.pump();
    check(service.admittedIdentities).deepEquals({'guest', 'alice'});
    receive(
      AdmissionRosterUpdated(
        id: 'removed',
        senderIdentity: 'keeper',
        recipientIdentity: 'guest',
        expiresAt: tester.binding.clock.now().add(const Duration(minutes: 1)),
        sessionIdentity: 'session',
        keeperGeneration: 'generation',
        revision: 4,
        members: const ['alice'],
      ),
    );
    await tester.pump();
    check(service.rosterTrust).equals(AdmissionRosterTrust.invalidated);
    check(service.admittedIdentities).isEmpty();
    service.handleTransportEvent(
      const TransportConnectionChanged(
        SessionTransportConnectionState.connected,
        reconnected: true,
      ),
    );
    await tester.pump();
    final refresh = sent.whereType<AdmissionRosterRequest>().last;
    snapshot('recovered', 4, ['guest', 'alice'], refresh.id);
    await tester.pump();
    check(service.admittedIdentities).deepEquals({'guest', 'alice'});
    receive(
      AdmissionRosterUpdated(
        id: 'generation-change',
        senderIdentity: 'keeper',
        recipientIdentity: 'guest',
        expiresAt: tester.binding.clock.now().add(const Duration(minutes: 1)),
        sessionIdentity: 'session',
        keeperGeneration: 'new-generation',
        revision: 1,
        members: const ['guest', 'alice'],
      ),
    );
    await tester.pump();
    check(service.rosterTrust).equals(AdmissionRosterTrust.invalidated);
    check(service.admittedIdentities).isEmpty();
    final generationRequest = sent.whereType<AdmissionRosterRequest>().last;
    receive(
      AdmissionRosterSnapshot(
        id: 'new-generation',
        senderIdentity: 'keeper',
        recipientIdentity: 'guest',
        expiresAt: tester.binding.clock.now().add(const Duration(minutes: 1)),
        sessionIdentity: 'session',
        keeperGeneration: 'new-generation',
        revision: 1,
        members: const ['guest', 'alice'],
        requestId: generationRequest.id,
      ),
    );
    await tester.pump();
    check(service.admittedIdentities).deepEquals({'guest', 'alice'});
    keeperIdentity = 'replacement';
    service.sync();
    check(service.rosterTrust).equals(AdmissionRosterTrust.invalidated);
    check(service.admittedIdentities).isEmpty();

    var closed = false;
    final closing = service.close().then((_) => closed = true);
    // Subscription cancellation can complete outside the widget fake-async zone.
    for (var i = 0; i < 20 && !closed; i++) {
      await tester.runAsync(() async {});
      await tester.pump(const Duration(milliseconds: 1));
    }
    check(closed).isTrue();
    await closing;
    container.dispose();
  });
}
