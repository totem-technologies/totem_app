import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/declined_session_participants.dart';
import 'package:totem_core/features/sessions/admission/keeper_admission_roster.dart';
import 'package:totem_core/features/sessions/admission/session_admission_overlay.dart';
import 'package:totem_core/features/sessions/admission/session_admission_scope.dart';
import 'package:totem_core/features/sessions/admission/session_admission_service.dart';
import 'package:totem_core/features/sessions/admission/session_admission_settings.dart';
import 'package:totem_core/features/sessions/admission/session_waiting_queue_button.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart'
    as session_state;
import 'package:totem_core/features/sessions/controllers/features/session_keeper_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/options/session_start_confirmation_dialog.dart';
import 'package:totem_core/features/sessions/services/session_commands.dart';
import 'package:totem_core/features/sessions/services/session_moderation_service.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/session_panels.dart';
import 'package:totem_core/features/sessions/widgets/session_side_panel.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:totem_core/shared/widgets/notifications.dart';

import '../../../setup.dart';
import '../livekit_mocks.dart';
import '../media/test_room_transport.dart';
import '../presentation/action_feedback_host.dart';
import '../session_test_mocks.dart';

DateTime _testNow() => DateTime.utc(2026);

class _AdmissionPreferences implements SessionAdmissionPreferences {
  _AdmissionPreferences({this.readError});

  Error? readError;
  final values = <String, String>{};
  int writeCount = 0;
  bool writesSucceed = true;
  Future<bool> Function(String key, String value)? beforeSet;
  Future<bool> Function(String key)? beforeRemove;

  @override
  String? getString(String key) {
    final error = readError;
    if (error != null) throw error;
    return values[key];
  }

  @override
  Future<bool> setString(String key, String value) async {
    writeCount++;
    if (!writesSucceed ||
        !await (beforeSet?.call(key, value) ?? Future.value(true))) {
      return false;
    }
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    if (!await (beforeRemove?.call(key) ?? Future.value(true))) return false;
    values.remove(key);
    return true;
  }
}

class _RemovalBackend extends Fake implements SessionModerationBackend {
  int calls = 0;
  final started = Completer<void>();
  Future<void> Function()? action;

  @override
  Future<void> remove(String identity) async {
    calls++;
    if (!started.isCompleted) started.complete();
    await action?.call();
  }
}

class _AdmissionRoom extends FakeRoom {
  _AdmissionRoom(super.participant);

  int transportCreations = 0;
  final listener = _AdmissionEvents();
  final remotes = <String, RemoteParticipant>{};

  @override
  UnmodifiableMapView<String, RemoteParticipant> get remoteParticipants =>
      UnmodifiableMapView(remotes);

  @override
  EventsListener<RoomEvent> createListener({bool synchronized = true}) => (() {
    transportCreations++;
    return listener;
  })();
}

class _AdmissionEvents implements EventsListener<RoomEvent> {
  final handlers = <Type, List<FutureOr<void> Function(Object?)>>{};

  @override
  CancelListenFunc on<E>(
    FutureOr<void> Function(E event) handler, {
    bool Function(E)? filter,
  }) {
    handlers.putIfAbsent(E, () => []).add((event) {
      final typed = event as E;
      if (filter == null || filter(typed)) return handler(typed);
    });
    return () async {};
  }

  Future<void> trigger<E>(E event) async {
    for (final handler in handlers[E] ?? <FutureOr<void> Function(Object?)>[]) {
      await handler(event);
    }
  }

  @override
  Future<bool> dispose() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RemoteParticipant extends Fake implements RemoteParticipant {
  _RemoteParticipant(this.identity);

  @override
  final String identity;
}

class _SessionController extends Mock implements SessionController {}

class _VideoPlaceholder extends StatefulWidget {
  const _VideoPlaceholder(this.builds);

  final ValueNotifier<int> builds;

  @override
  State<_VideoPlaceholder> createState() => _VideoPlaceholderState();
}

class _VideoPlaceholderState extends State<_VideoPlaceholder> {
  @override
  Widget build(BuildContext context) {
    widget.builds.value++;
    return const SizedBox.expand();
  }
}

class _AdmissionOverlayHost extends ConsumerWidget {
  const _AdmissionOverlayHost({
    required this.videoBuilds,
    this.includeDock = false,
  });

  final ValueNotifier<int> videoBuilds;
  final bool includeDock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SessionPanels(
      sessionSlug: 'session',
      session: ref.watch(currentSessionProvider),
      connectionState: RoomConnectionState.connected,
      roomStatus: RoomStatus.active,
      child: Column(
        children: [
          Expanded(child: _VideoPlaceholder(videoBuilds)),
          SessionAdmissionQueueControl(
            child: SizedBox(key: SessionActionBar.actionBarKey, height: 64),
          ),
        ],
      ),
    );
  }
}

class _AdmissionHarness {
  _AdmissionHarness({
    _AdmissionPreferences? preferences,
    Future<SessionAdmissionPreferences> Function(Ref ref)? preferencesOverride,
  }) : preferences = preferences ?? _AdmissionPreferences() {
    final participant = MockLocalParticipant('keeper');
    when(
      () => participant.publishData(
        any(),
        reliable: any(named: 'reliable'),
        topic: any(named: 'topic'),
        destinationIdentities: any(named: 'destinationIdentities'),
      ),
    ).thenAnswer((invocation) async {
      final packet = AdmissionProtocol.decode(
        invocation.positionalArguments.single as List<int>,
        senderIdentity: 'keeper',
        now: _now(),
      );
      if (packet != null) {
        sent.add(packet);
        await afterSend?.call(packet);
      }
    });
    room = _AdmissionRoom(participant);
    session = _SessionController();
    when(() => session.updateAdmittedMediaRecipients(any())).thenAnswer((
      invocation,
    ) {
      mediaRecipients.add(
        Set<String>.from(invocation.positionalArguments.single as Set<String>),
      );
    });
    state = MockSessionRoomState();
    when(() => session.room).thenReturn(room);
    when(
      () => session.transport,
    ).thenAnswer((_) => _transportFor(session.room!));
    when(() => state.connection).thenReturn(
      const session_state.ConnectionState(
        phase: session_state.SessionPhase.connected,
        state: session_state.RoomConnectionState.connected,
      ),
    );
    when(() => state.roomState).thenReturn(
      const RoomState(
        keeper: 'keeper',
        nextSpeaker: Omittable(''),
        currentSpeaker: Omittable(''),
        status: RoomStatus.active,
        turnState: TurnState.idle,
        sessionSlug: 'session',
        statusDetail: RoomStateStatusDetailActive(ActiveDetail()),
        talkingOrder: [],
        version: 1,
        roundNumber: 1,
      ),
    );
    _preferencesOverride = preferencesOverride;
  }

  final DateTime Function() _now = _testNow;
  var _requestCount = 0;
  final _AdmissionPreferences preferences;
  late Ref serviceRef;
  final _transports = Map<Room, TestRoomTransport>.identity();
  SessionAdmissionService? _admissionService;
  TestRoomTransport _transportFor(Room room) =>
      _transports.putIfAbsent(room, () {
        final transport = TestRoomTransport(room);
        final subscription = transport.events.listen((event) {
          if (identical(session.transport, transport)) {
            _admissionService?.handleTransportEvent(event);
          }
        });
        addTearDown(() async {
          await subscription.cancel();
          await transport.dispose();
        });
        return transport;
      });
  bool expectShutdownFailure = false;
  final shutdownErrors = <Object>[];
  final sent = <AdmissionPacket>[];
  final mediaRecipients = <Set<String>>[];
  Future<void> Function(AdmissionPacket packet)? afterSend;
  late final _AdmissionRoom room;
  late final _SessionController session;
  late final MockSessionRoomState state;
  late final Future<SessionAdmissionPreferences> Function(Ref ref)?
  _preferencesOverride;

  List<Override> get overrides => [
    sessionAdmissionPreferencesProvider.overrideWith(
      _preferencesOverride ?? (ref) async => preferences,
    ),
    currentSessionProvider.overrideWith((ref) {
      serviceRef = ref;
      final service = SessionAdmissionService(ref, session, now: _testNow);
      _admissionService = service;
      when(() => session.admission).thenReturn(service);
      when(() => session.admissionState).thenAnswer((_) => state);
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
      when(() => session.session).thenReturn(null);
      ref
        ..onDispose(
          () => unawaited(
            service.close().catchError((Object error, StackTrace stack) {
              if (!expectShutdownFailure) {
                Error.throwWithStackTrace(error, stack);
              }
              shutdownErrors.add(error);
            }),
          ),
        )
        ..listen(currentSessionStateProvider, (_, _) => service.sync());
      service.sync();
      return session;
    }),
    currentSessionStateProvider.overrideWithValue(state),
    resolveCurrentScreenProvider.overrideWith((ref) => RoomScreen.listening),
    currentSessionEventProvider.overrideWith((ref) => null),
    isCurrentUserKeeperProvider.overrideWith((ref) => true),
    userProfileProvider('guest').overrideWith(
      (ref) => PublicUserSchema(
        profileAvatarType: ProfileAvatarTypeEnum.td,
        dateCreated: DateTime(2024),
      ),
    ),
  ];

  AdmissionRequest request(
    String id, {
    String sender = 'guest',
    String name = 'Guest',
    DateTime? expiresAt,
  }) => AdmissionRequest(
    id: id,
    senderIdentity: sender,
    recipientIdentity: 'keeper',
    expiresAt: expiresAt ?? _nextRequestExpiration(),
    displayName: name,
  );

  DateTime _nextRequestExpiration() =>
      _now().add(Duration(minutes: 5, milliseconds: _requestCount++));

  DateTime expiration() => _now().add(const Duration(minutes: 5));

  Future<void> sendRequest(AdmissionRequest request) => sendPacket(request);

  Future<void> sendPacket(AdmissionPacket packet) => room.listener.trigger(
    DataReceivedEvent(
      data: AdmissionProtocol.encode(packet),
      participant: _RemoteParticipant(packet.senderIdentity),
      topic: AdmissionProtocol.topic,
    ),
  );
}

void main() {
  const removalRosterKey = 'session_admission_keeper_roster:session:keeper';
  const removalJournalKey =
      'session_admission_revocations:["session","keeper"]';

  Future<(_AdmissionHarness, ProviderContainer, SessionAdmissionService)>
  removalSession(_AdmissionPreferences preferences) async {
    setupAppConfig();
    preferences.values.putIfAbsent(
      removalRosterKey,
      () => jsonEncode({
        'version': 1,
        'generation': 'removal-tests',
        'revision': 1,
        'members': ['guest', 'another'],
        'awaitingReadiness': <String>[],
      }),
    );
    final harness = _AdmissionHarness(preferences: preferences);
    final container = ProviderContainer(overrides: harness.overrides);
    final retained = container.listen(currentSessionProvider, (_, _) {});
    final service = container.read(currentSessionProvider)!.admission;
    await container.read(
      keeperAdmissionRosterProvider('session', 'keeper').future,
    );
    await container.read(
      declinedSessionParticipantsProvider('session', 'keeper').future,
    );
    service.sync();
    await service.synchronized;
    addTearDown(() async {
      try {
        await service.close();
      } catch (error) {
        if (!harness.expectShutdownFailure) rethrow;
        harness.shutdownErrors.add(error);
      } finally {
        retained.close();
        container.dispose();
      }
    });
    return (harness, container, service);
  }

  SessionModerationService moderationFor(
    _AdmissionHarness harness,
    SessionAdmissionService admission,
    _RemovalBackend backend,
  ) {
    final moderation = SessionModerationService(
      backend: backend,
      state: () => harness.session.admissionState,
      isKeeper: () => true,
      transport: () => harness.session.transport,
      applyState: (_) {},
      prepareRemoval: admission.prepareRemoval,
      markRemoved: (_) {},
      leave: () async {},
      onError: (_, _) {},
      captureValidity: () =>
          () => true,
    );
    addTearDown(moderation.dispose);
    return moderation;
  }

  Completer<void> observeControllerClosure(SessionAdmissionService service) {
    final closed = Completer<void>();
    final subscription = service.keeperController!.changes.listen(
      (_) {},
      onDone: closed.complete,
    );
    addTearDown(subscription.cancel);
    return closed;
  }

  void endSession(_AdmissionHarness harness) {
    final previous = harness.session.admissionState.roomState;
    when(() => harness.state.roomState).thenReturn(
      previous.copyWith(
        status: RoomStatus.ended,
        statusDetail: const RoomStateStatusDetailEnded(
          EndedDetail(reason: EndReason.keeperEnded),
        ),
      ),
    );
  }

  group('admission persistence teardown', () {
    test(
      'concurrent close waits for final roster persistence before releasing controllers',
      () async {
        final preferences = _AdmissionPreferences();
        final (harness, container, service) = await removalSession(preferences);
        final controllerClosed = observeControllerClosure(service);
        final saving = Completer<void>();
        final saved = Completer<bool>();
        preferences.beforeSet = (key, _) {
          if (key != removalRosterKey) return Future.value(true);
          if (!saving.isCompleted) saving.complete();
          return saved.future;
        };
        var completed = false;
        final close = service.close();
        check(service.close()).identicalTo(close);
        unawaited(close.then((_) => completed = true));
        await saving.future;
        await container.pump();
        check(completed).isFalse();
        check(controllerClosed.isCompleted).isFalse();
        check(await service.admitAll()).isFalse();
        await service.decide(harness.request('while-closing'), true);
        final published = harness.sent.length;
        await harness.sendRequest(harness.request('while-closing'));
        check(harness.sent.length).equals(published);
        saved.complete(true);
        await close;
        await controllerClosed.future;
        check(completed).isTrue();
        check(service.keeperController).isNull();
        final writes = preferences.writeCount;
        await service.close();
        await service.disconnect();
        check(preferences.writeCount).equals(writes);
      },
    );

    test(
      'close drains an in-flight sync without recreating its replacement controller',
      () async {
        final preferences = _AdmissionPreferences();
        final (harness, container, service) = await removalSession(preferences);
        final controllerClosed = observeControllerClosure(service);
        final saving = Completer<void>();
        final saved = Completer<bool>();
        preferences.beforeSet = (key, _) {
          if (key != removalRosterKey) return Future.value(true);
          if (!saving.isCompleted) saving.complete();
          return saved.future;
        };
        final replacement = _AdmissionRoom(harness.room.participant);
        when(() => harness.session.room).thenReturn(replacement);
        service.sync();
        await saving.future;
        var completed = false;
        final close = service.close();
        unawaited(close.then((_) => completed = true));
        await container.pump();
        check(completed).isFalse();
        saved.complete(true);
        await close;
        await controllerClosed.future;
        check(service.keeperController).isNull();
        final updates = harness.mediaRecipients.length;
        final published = harness.sent.length;
        await replacement.listener.trigger(
          DataReceivedEvent(
            data: AdmissionProtocol.encode(harness.request('late-sync')),
            participant: _RemoteParticipant('guest'),
            topic: AdmissionProtocol.topic,
          ),
        );
        await container.pump();
        check(harness.mediaRecipients.length).equals(updates);
        check(harness.sent.length).equals(published);
      },
    );

    test(
      'ending waits for an earlier save and leaves storage cleared after close',
      () async {
        final preferences = _AdmissionPreferences();
        final (harness, container, service) = await removalSession(preferences);
        final storeProvider = keeperAdmissionRosterProvider(
          'session',
          'keeper',
        );
        final store = await container.read(storeProvider.future);
        store.replace(['saved-before-end'], store.revision + 1);
        final saving = Completer<void>();
        final saved = Completer<bool>();
        var firstWrite = true;
        preferences.beforeSet = (key, _) {
          if (key != removalRosterKey || !firstWrite) return Future.value(true);
          firstWrite = false;
          saving.complete();
          return saved.future;
        };
        final previousSave = container.read(storeProvider.notifier).persist();
        await saving.future;
        endSession(harness);
        service.sync();
        await container.pump();
        check(preferences.values.containsKey(removalRosterKey)).isTrue();
        saved.complete(true);
        await previousSave;
        await service.synchronized;
        check(preferences.values.containsKey(removalRosterKey)).isFalse();
        await service.close();
        check(preferences.values.containsKey(removalRosterKey)).isFalse();
      },
    );

    test(
      'a failed teardown save still closes controllers and reports the storage failure',
      () async {
        final preferences = _AdmissionPreferences();
        final (harness, container, service) = await removalSession(preferences);
        final controllerClosed = observeControllerClosure(service);
        harness.expectShutdownFailure = true;
        preferences.beforeSet = (key, _) async => key != removalRosterKey;
        final persisted = preferences.values[removalRosterKey];
        await check(service.close()).throws<StateError>();
        await controllerClosed.future;
        check(service.keeperController).isNull();
        check(preferences.values[removalRosterKey]).equals(persisted);
        final updates = harness.mediaRecipients.length;
        final published = harness.sent.length;
        await harness.sendRequest(harness.request('after-failed-close'));
        await container.pump();
        check(harness.mediaRecipients.length).equals(updates);
        check(harness.sent.length).equals(published);
        await check(service.close()).throws<StateError>();
      },
    );

    test(
      'successful final save recovers an earlier in-flight roster write failure',
      () async {
        final preferences = _AdmissionPreferences();
        final (harness, _, service) = await removalSession(preferences);
        final firstWriteFailed = Completer<void>();
        var rosterWrites = 0;
        preferences.beforeSet = (key, _) async {
          if (key != removalRosterKey) return true;
          rosterWrites++;
          if (rosterWrites == 1) {
            firstWriteFailed.complete();
            return false;
          }
          return true;
        };

        service.keeperController!.revoke('guest');
        await firstWriteFailed.future;
        await service.close();

        check(service.keeperController).isNull();
        check(service.recoveryError).isNull();
        check(service.error).isNull();
        check(rosterWrites).equals(2);

        final (_, _, replacement) = await removalSession(preferences);
        check(replacement.keeperController).isNotNull();
        check(replacement.admittedIdentities.contains('guest')).isFalse();
        check(harness.shutdownErrors).isEmpty();
      },
    );

    for (final failingKey in [
      removalRosterKey,
      'session_admission_declined_participants:session:keeper',
    ]) {
      test(
        'end clearing attempts every store and reports failure for $failingKey',
        () async {
          final preferences = _AdmissionPreferences();
          const declinedKey =
              'session_admission_declined_participants:session:keeper';
          preferences.values[declinedKey] = jsonEncode(['declined']);
          final (harness, _, service) = await removalSession(preferences);
          final controllerClosed = observeControllerClosure(service);
          harness.expectShutdownFailure = true;
          final attempted = <String>[];
          preferences.beforeRemove = (key) async {
            attempted.add(key);
            return key != failingKey;
          };
          endSession(harness);
          service.sync();
          await service.synchronized;
          await controllerClosed.future;
          await check(service.close()).throws<StateError>();
          check(attempted).contains(removalRosterKey);
          check(attempted).contains(declinedKey);
          check(preferences.values.containsKey(failingKey)).isTrue();
          check(
            preferences.values.containsKey(
              failingKey == removalRosterKey ? declinedKey : removalRosterKey,
            ),
          ).isFalse();
        },
      );
    }

    test(
      'disconnect followed by close releases one controller and rejects stale packets',
      () async {
        final preferences = _AdmissionPreferences();
        final (harness, container, service) = await removalSession(preferences);
        final controllerClosed = observeControllerClosure(service);
        await Future.wait([service.disconnect(), service.disconnect()]);
        await controllerClosed.future;
        final writes = preferences.writeCount;
        final published = harness.sent.length;
        await service.close();
        await harness.sendRequest(harness.request('after-disconnect-close'));
        await container.pump();
        check(preferences.writeCount).equals(writes);
        check(harness.sent.length).equals(published);
        check(service.keeperController).isNull();
      },
    );

    test(
      'a new entry waits for the previous teardown and reloads its final roster',
      () async {
        final preferences = _AdmissionPreferences();
        final (oldHarness, oldContainer, oldService) = await removalSession(
          preferences,
        );
        final provider = keeperAdmissionRosterProvider('session', 'keeper');
        final store = await oldContainer.read(provider.future);
        store.replace(['final-member'], store.revision + 1);
        final saving = Completer<void>();
        final saved = Completer<bool>();
        var firstWrite = true;
        preferences.beforeSet = (key, _) {
          if (key != removalRosterKey || !firstWrite) return Future.value(true);
          firstWrite = false;
          saving.complete();
          return saved.future;
        };
        final staleReplacement = _AdmissionRoom(oldHarness.room.participant);
        when(() => oldHarness.session.room).thenReturn(staleReplacement);
        oldService.sync();
        await saving.future;
        final closing = oldService.close();
        final replacementHarness = _AdmissionHarness(preferences: preferences);
        final replacementContainer = ProviderContainer(
          overrides: replacementHarness.overrides,
        );
        final retained = replacementContainer.listen(
          currentSessionProvider,
          (_, _) {},
        );
        final replacement = replacementContainer
            .read(currentSessionProvider)!
            .admission;
        final ready = Completer<void>();
        void observeReady() {
          if (replacement.keeperController != null && !ready.isCompleted) {
            ready.complete();
          }
        }

        replacement.addListener(observeReady);
        addTearDown(() => replacement.removeListener(observeReady));
        addTearDown(() async {
          await replacement.close();
          retained.close();
          replacementContainer.dispose();
        });
        final loadingRoster = replacementContainer.read(provider.future);
        final loadingDeclines = replacementContainer.read(
          declinedSessionParticipantsProvider('session', 'keeper').future,
        );
        replacement.sync();
        await replacementContainer.pump();
        check(replacement.keeperController).isNull();
        saved.complete(true);
        await Future.wait([closing, loadingRoster, loadingDeclines]);
        replacement.sync();
        await ready.future;
        check(replacement.admittedIdentities).deepEquals({'final-member'});
        final updates = replacementHarness.mediaRecipients.length;
        await oldHarness.sendRequest(oldHarness.request('old-entry'));
        await staleReplacement.listener.trigger(
          DataReceivedEvent(
            data: AdmissionProtocol.encode(
              oldHarness.request('old-sync-result'),
            ),
            participant: _RemoteParticipant('guest'),
            topic: AdmissionProtocol.topic,
          ),
        );
        await replacementContainer.pump();
        check(replacementHarness.mediaRecipients.length).equals(updates);
        check(oldService.keeperController).isNull();
      },
    );

    test(
      'a replacement retries recovery after the previous final save fails',
      () async {
        final preferences = _AdmissionPreferences();
        final (oldHarness, _, oldService) = await removalSession(preferences);
        oldHarness.expectShutdownFailure = true;
        preferences.beforeSet = (key, _) async => key != removalRosterKey;
        final harness = _AdmissionHarness(preferences: preferences);
        final container = ProviderContainer(overrides: harness.overrides);
        final retained = container.listen(currentSessionProvider, (_, _) {});
        final service = container.read(currentSessionProvider)!.admission;
        addTearDown(() async {
          await service.close();
          retained.close();
          container.dispose();
        });
        final failed = Completer<void>();
        final ready = Completer<void>();
        void observeRecovery() {
          if (service.error != null && !failed.isCompleted) {
            failed.complete();
          }
          if (service.keeperController != null && !ready.isCompleted) {
            ready.complete();
          }
        }

        service.addListener(observeRecovery);
        addTearDown(() => service.removeListener(observeRecovery));
        observeRecovery();
        await failed.future;
        check(oldService.keeperController).isNull();
        check(service.keeperController).isNull();
        check(service.admittedIdentities).isEmpty();
        check(
          harness.mediaRecipients.expand((recipients) => recipients),
        ).isEmpty();
        preferences.beforeSet = null;
        await service.retryRecovery();
        service.sync();
        await ready.future;
        check(service.admittedIdentities).deepEquals({'guest', 'another'});
        check(harness.mediaRecipients.last).deepEquals({'guest', 'another'});
        check(service.error).isNull();
      },
    );

    test(
      'provider disposal while close is saving does not read an unmounted Ref',
      () async {
        final preferences = _AdmissionPreferences();
        final (_, container, service) = await removalSession(preferences);
        final controllerClosed = observeControllerClosure(service);
        final saving = Completer<void>();
        final saved = Completer<bool>();
        preferences.beforeSet = (key, _) {
          if (key != removalRosterKey) return Future.value(true);
          if (!saving.isCompleted) saving.complete();
          return saved.future;
        };
        final closing = service.close();
        await saving.future;
        container.dispose();
        saved.complete(true);
        await closing;
        await controllerClosed.future;
        check(preferences.values.containsKey(removalRosterKey)).isTrue();
      },
    );

    test(
      'close drains already-started revocation persistence before returning',
      () async {
        final preferences = _AdmissionPreferences();
        final (harness, container, service) = await removalSession(preferences);
        final removal = await service.prepareRemoval('guest');
        final saving = Completer<void>();
        final saved = Completer<bool>();
        preferences.beforeSet = (key, _) {
          if (key != removalRosterKey) return Future.value(true);
          if (!saving.isCompleted) saving.complete();
          return saved.future;
        };
        final committed = removal.commit();
        await saving.future;
        var completed = false;
        final closing = service.close();
        unawaited(closing.then((_) => completed = true));
        await container.pump();
        check(completed).isFalse();
        check(harness.mediaRecipients.last.contains('guest')).isFalse();
        saved.complete(true);
        await Future.wait([committed, closing]);
        check(preferences.values.containsKey(removalJournalKey)).isFalse();
        final payload =
            jsonDecode(preferences.values[removalRosterKey]!) as Map;
        check((payload['members'] as List).contains('guest')).isFalse();
        check((payload['revoked'] as List).contains('guest')).isTrue();
      },
    );
  });

  test('removal intent must be durable before preparation succeeds', () async {
    final preferences = _AdmissionPreferences();
    final (harness, _, service) = await removalSession(preferences);
    preferences.beforeSet = (key, _) async => key != removalJournalKey;
    final backend = _RemovalBackend();
    final moderation = moderationFor(harness, service, backend);

    await check(moderation.removeParticipant('guest')).throws<StateError>();

    check(backend.calls).equals(0);

    check(service.admittedIdentities).contains('guest');
    check(harness.mediaRecipients.last).contains('guest');
    check(preferences.values.containsKey(removalJournalKey)).isFalse();
  });

  for (final cleanupFails in [false, true]) {
    test(
      'backend rejection preserves admission even when journal cleanup fails ($cleanupFails)',
      () async {
        final preferences = _AdmissionPreferences();
        final (harness, _, service) = await removalSession(preferences);
        const rejection = ApiError<RoomState, RoomErrorResponse>(
          statusCode: 403,
          error: RoomErrorResponse(
            code: ErrorCode.notKeeper,
            message: 'Rejected',
          ),
        );
        final backend = _RemovalBackend()..action = () async => throw rejection;
        final moderation = moderationFor(harness, service, backend);
        preferences.beforeRemove = (key) async =>
            !cleanupFails || key != removalJournalKey;

        if (cleanupFails) {
          await check(
            moderation.removeParticipant('guest'),
          ).throws<SessionCommandException>();
          check(
            moderation.lastFailure?.kind,
          ).equals(SessionCommandFailureKind.recoveryRequired);
        } else {
          await check(
            moderation.removeParticipant('guest'),
          ).throws<ApiError<RoomState, RoomErrorResponse>>();
        }
        check(backend.calls).equals(1);
        check(service.admittedIdentities).contains('guest');
        check(harness.mediaRecipients.last).contains('guest');
        check(
          preferences.values.containsKey(removalJournalKey),
        ).equals(cleanupFails);
        preferences.beforeRemove = null;
        await service.retryRecovery();
        check(preferences.values.containsKey(removalJournalKey)).isFalse();
        check(service.admittedIdentities).contains('guest');
        service.requireRemovalReady();
      },
    );
  }

  test(
    'confirmed removal restricts live media before final persistence completes',
    () async {
      final preferences = _AdmissionPreferences();
      final (harness, container, service) = await removalSession(preferences);
      final backend = _RemovalBackend();
      final backendResult = Completer<void>();
      backend.action = () => backendResult.future;
      final moderation = moderationFor(harness, service, backend);
      final saving = Completer<void>();
      final stored = Completer<bool>();
      preferences.beforeSet = (key, _) {
        if (key != removalRosterKey) return Future.value(true);
        if (!saving.isCompleted) saving.complete();
        return stored.future;
      };

      final completing = moderation.removeParticipant('guest');
      await backend.started.future;
      await container.pump();
      check(preferences.values.containsKey(removalJournalKey)).isTrue();
      check(service.admittedIdentities).contains('guest');
      backendResult.complete();
      await saving.future;
      check(service.admittedIdentities.contains('guest')).isFalse();
      check(harness.mediaRecipients.last.contains('guest')).isFalse();
      check(service.admittedIdentities).contains('another');
      check(preferences.values.containsKey(removalJournalKey)).isTrue();
      stored.complete(true);
      await completing;
      check(backend.calls).equals(1);
      check(preferences.values.containsKey(removalJournalKey)).isFalse();
      service.requireRemovalReady();
    },
  );

  for (final failure in ['roster', 'journal update', 'journal cleanup']) {
    test(
      'committed removal survives $failure failure and successful recovery retry',
      () async {
        final preferences = _AdmissionPreferences();
        final (harness, container, service) = await removalSession(preferences);
        final removal = await service.prepareRemoval('guest');
        preferences
          ..beforeSet = (key, _) async {
            return !((failure == 'roster' && key == removalRosterKey) ||
                (failure == 'journal update' && key == removalJournalKey));
          }
          ..beforeRemove = (key) async {
            return failure != 'journal cleanup' || key != removalJournalKey;
          };

        await check(removal.commit()).throws<StateError>();

        check(service.admittedIdentities.contains('guest')).isFalse();
        check(harness.mediaRecipients.last.contains('guest')).isFalse();
        check(preferences.values.containsKey(removalJournalKey)).isTrue();
        check(service.requireRemovalReady).throws<StateError>();
        preferences
          ..beforeSet = null
          ..beforeRemove = null;
        if (failure == 'journal update') {
          // The durable record still says "intent", but this active service
          // knows the backend committed. Reconnecting must not downgrade it.
          final replacement = _AdmissionRoom(harness.room.participant);
          when(() => harness.session.room).thenReturn(replacement);
          service.sync();
          await service.synchronized;
          check(service.unresolvedRemovals).isEmpty();
          check(service.admittedIdentities.contains('guest')).isFalse();
          check(harness.mediaRecipients.last.contains('guest')).isFalse();
          final updates = harness.mediaRecipients.length;
          await harness.sendRequest(harness.request('stale-old-room'));
          await container.pump();
          check(harness.mediaRecipients.length).equals(updates);

          service.setApprovalRequired(false);
          await service.synchronized;
          final reconnecting = harness.request('revoked-reconnect');
          for (final packet in [
            reconnecting,
            AdmissionProtocol.joined(reconnecting),
          ]) {
            await replacement.listener.trigger(
              DataReceivedEvent(
                data: AdmissionProtocol.encode(packet),
                participant: _RemoteParticipant('guest'),
                topic: AdmissionProtocol.topic,
              ),
            );
          }
          await container.pump();
          check(
            harness.sent.whereType<AdmissionDecision>().where(
              (decision) => decision.id == reconnecting.id && decision.approved,
            ),
          ).isEmpty();
          check(service.admittedIdentities.contains('guest')).isFalse();
          check(harness.mediaRecipients.last.contains('guest')).isFalse();
        } else {
          await service.retryRecovery();
        }
        check(preferences.values.containsKey(removalJournalKey)).isFalse();
        check(service.admittedIdentities.contains('guest')).isFalse();
        service.requireRemovalReady();
      },
    );
  }

  test(
    'unknown removal remains quarantined through recovery until explicitly reconciled',
    () async {
      final preferences = _AdmissionPreferences();
      final (harness, _, service) = await removalSession(preferences);
      final removal = await service.prepareRemoval('guest');
      await removal.unknown();
      check(service.admittedIdentities.contains('guest')).isFalse();
      check(harness.mediaRecipients.last.contains('guest')).isFalse();
      await service.retryRecovery();
      check(preferences.values.containsKey(removalJournalKey)).isTrue();
      check(service.requireRemovalReady).throws<StateError>();

      await service.reconcileRemoval('guest', backendRemoved: true);
      check(preferences.values.containsKey(removalJournalKey)).isFalse();
      check(service.admittedIdentities.contains('guest')).isFalse();
      service.requireRemovalReady();
    },
  );

  test('verified removal reconciles after admission detaches', () async {
    final preferences = _AdmissionPreferences();
    final (_, container, service) = await removalSession(preferences);
    final removal = await service.prepareRemoval('guest');
    await removal.unknown();
    await service.disconnect();

    await service.reconcileRemoval('guest', backendRemoved: true);

    final roster = await container.read(
      keeperAdmissionRosterProvider('session', 'keeper').future,
    );
    check(roster.members).not((members) => members.contains('guest'));
    check(roster.revoked).contains('guest');
    check(preferences.values.containsKey(removalJournalKey)).isFalse();
    check(service.unresolvedRemovals.contains('guest')).isFalse();
    check(service.error).isNull();
  });

  test('detach waits for an in-flight removal reconciliation', () async {
    final preferences = _AdmissionPreferences();
    final (_, _, service) = await removalSession(preferences);
    final removal = await service.prepareRemoval('guest');
    await removal.unknown();
    final savingRoster = Completer<void>();
    final savedRoster = Completer<bool>();
    preferences.beforeSet = (key, _) {
      if (key != removalRosterKey) return Future.value(true);
      if (!savingRoster.isCompleted) savingRoster.complete();
      return savedRoster.future;
    };

    final reconciling = service.reconcileRemoval('guest', backendRemoved: true);
    await savingRoster.future;
    var detached = false;
    final disconnecting = service.disconnect().then((_) => detached = true);
    check(detached).isFalse();

    savedRoster.complete(true);
    await Future.wait([reconciling, disconnecting]);
    check(detached).isTrue();
    check(preferences.values.containsKey(removalJournalKey)).isFalse();
    check(service.unresolvedRemovals.contains('guest')).isFalse();
  });

  test(
    'consecutive removals persist both revocations and cannot be auto-admitted again',
    () async {
      final preferences = _AdmissionPreferences();
      final (harness, _, service) = await removalSession(preferences);
      await (await service.prepareRemoval('guest')).commit();
      await (await service.prepareRemoval('another')).commit();
      service.setApprovalRequired(false);
      await service.synchronized;
      await harness.sendRequest(harness.request('removed-again'));
      await Future<void>.value();

      check(service.admittedIdentities.contains('guest')).isFalse();
      check(service.admittedIdentities.contains('another')).isFalse();
      check(harness.mediaRecipients.last.contains('guest')).isFalse();
      check(preferences.values.containsKey(removalJournalKey)).isFalse();
      final persisted =
          jsonDecode(preferences.values[removalRosterKey]!) as Map;
      check((persisted['members'] as List).contains('guest')).isFalse();
      check((persisted['members'] as List).contains('another')).isFalse();
    },
  );

  test(
    'committed removal after service disposal remains revoked on re-entry without stale notifications',
    () async {
      final preferences = _AdmissionPreferences();
      final (oldHarness, _, oldService) = await removalSession(preferences);
      final removal = await oldService.prepareRemoval('guest');
      await oldService.close();
      await check(removal.commit()).throws<StateError>();
      check(preferences.values.containsKey(removalJournalKey)).isTrue();
      final previousMediaUpdates = oldHarness.mediaRecipients.length;

      final (replacement, _, service) = await removalSession(preferences);
      check(service.admittedIdentities.contains('guest')).isFalse();
      check(replacement.mediaRecipients.last.contains('guest')).isFalse();
      check(oldHarness.mediaRecipients.length).equals(previousMediaUpdates);
      await service.retryRecovery();
      check(service.admittedIdentities.contains('guest')).isFalse();
    },
  );
  test(
    'unfinished durable intent stays quarantined after re-entry until outcome is verified',
    () async {
      final preferences = _AdmissionPreferences();
      final (_, _, oldService) = await removalSession(preferences);
      await oldService.prepareRemoval('guest');
      await oldService.close();

      final (replacement, _, service) = await removalSession(preferences);
      check(service.admittedIdentities.contains('guest')).isFalse();
      check(replacement.mediaRecipients.last.contains('guest')).isFalse();
      check(preferences.values.containsKey(removalJournalKey)).isTrue();
      check(service.requireRemovalReady).throws<StateError>();
      await service.reconcileRemoval('guest', backendRemoved: false);
      check(service.admittedIdentities).contains('guest');
      check(replacement.mediaRecipients.last).contains('guest');
      check(preferences.values.containsKey(removalJournalKey)).isFalse();
      service.requireRemovalReady();
    },
  );

  test(
    'repeated failed recovery cannot clear journal from an already mutated roster',
    () async {
      final preferences = _AdmissionPreferences();
      preferences.values[removalJournalKey] = jsonEncode({
        'guest': 'committed',
      });
      preferences.beforeSet = (key, _) async => key != removalRosterKey;
      final (_, _, service) = await removalSession(preferences);
      check(preferences.values.containsKey(removalJournalKey)).isTrue();
      check(service.admittedIdentities.contains('guest')).isFalse();

      await service.retryRecovery();
      await service.synchronized;
      check(preferences.values.containsKey(removalJournalKey)).isTrue();
      check(service.admittedIdentities.contains('guest')).isFalse();
      preferences.beforeSet = null;
      await service.retryRecovery();
      await service.synchronized;
      check(preferences.values.containsKey(removalJournalKey)).isFalse();
      check(service.admittedIdentities.contains('guest')).isFalse();
      service.requireRemovalReady();
    },
  );

  test(
    'corrupt removal journal can be explicitly reset and admission recovers',
    () async {
      final preferences = _AdmissionPreferences();
      preferences.values[removalJournalKey] = '{not-json';
      final (_, _, service) = await removalSession(preferences);

      check(service.hasCorruptRemovalJournal).isTrue();
      check(service.admittedIdentities).isEmpty();
      check(preferences.values.containsKey(removalJournalKey)).isTrue();

      await service.resetCorruptRemovalJournal();

      check(service.hasCorruptRemovalJournal).isFalse();
      check(service.recoveryError).isNull();
      check(preferences.values.containsKey(removalJournalKey)).isFalse();
      check(preferences.values.containsKey(removalRosterKey)).isFalse();
      check(service.admittedIdentities).isEmpty();
      service.requireRemovalReady();
    },
  );

  test(
    'failed corrupt journal reset preserves fail-closed admission',
    () async {
      final preferences = _AdmissionPreferences();
      preferences.values[removalJournalKey] = '{not-json';
      final (_, _, service) = await removalSession(preferences);
      preferences.beforeRemove = (key) async => key != removalJournalKey;

      await check(service.resetCorruptRemovalJournal()).throws<StateError>();

      check(service.hasCorruptRemovalJournal).isTrue();
      check(service.admittedIdentities).isEmpty();
      check(preferences.values.containsKey(removalJournalKey)).isTrue();
    },
  );

  test(
    'session owns admission and roster permissions without a widget',
    () async {
      final harness = _AdmissionHarness();
      final container = ProviderContainer(overrides: harness.overrides);
      final retained = container.listen(currentSessionProvider, (_, _) {});
      final service = container.read(currentSessionProvider)!.admission;
      try {
        await container.read(
          keeperAdmissionRosterProvider('session', 'keeper').future,
        );
        await container.read(
          declinedSessionParticipantsProvider('session', 'keeper').future,
        );
        service.sync();
        await service.synchronized;
        final controller = service.keeperController!;
        service
          ..sync()
          ..sync();
        await service.synchronized;
        check(identical(controller, service.keeperController)).isTrue();
        check(harness.room.transportCreations).equals(1);
        await harness.sendRequest(harness.request('headless'));
        await Future<void>.value();
        check(controller.requests).length.equals(1);
        final request = controller.requests.single;
        await service.decide(request, true);
        await harness.sendPacket(AdmissionProtocol.joined(request));
        await Future<void>.value();
        check(
          container.read(admittedSessionParticipantIdentitiesProvider),
        ).contains('guest');
        check(harness.mediaRecipients.last).contains('guest');
        await service.revokeRemovedParticipant('guest');
        await Future<void>.value();
        check(
          container
              .read(admittedSessionParticipantIdentitiesProvider)
              .contains('guest'),
        ).isFalse();
        check(harness.mediaRecipients.last.contains('guest')).isFalse();
        final replacement = _AdmissionRoom(harness.room.participant);
        when(() => harness.session.room).thenReturn(replacement);
        service.sync();
        await service.synchronized;
        check(identical(controller, service.keeperController)).isFalse();
        check(replacement.transportCreations).equals(1);
        final before = harness.mediaRecipients.length;
        await harness.sendRequest(harness.request('stale'));
        await Future<void>.value();
        check(harness.mediaRecipients.length).equals(before);
        final completeRemoval = await service.prepareRemoval('late-guest');
        await service.close();
        await check(completeRemoval.commit()).throws<StateError>();
        check(
          harness.preferences.values.containsKey(removalJournalKey),
        ).isTrue();
        await replacement.listener.trigger(
          DataReceivedEvent(
            data: AdmissionProtocol.encode(harness.request('disposed')),
            participant: _RemoteParticipant('guest'),
            topic: AdmissionProtocol.topic,
          ),
        );
        await Future<void>.value();
        check(harness.mediaRecipients.length).equals(before);
      } finally {
        await service.close();
        retained.close();
        container.dispose();
      }
    },
  );

  Future<void> waitForAdmissionReady(
    WidgetTester tester,
    SessionAdmissionService service,
  ) async {
    final ready = Completer<void>();
    void observeReady() {
      if ((service.keeperController != null || service.error != null) &&
          !ready.isCompleted) {
        ready.complete();
      }
    }

    service.addListener(observeReady);
    try {
      observeReady();
      for (var frame = 0; !ready.isCompleted && frame < 20; frame++) {
        await tester.pump();
      }
      check(
        ready.isCompleted,
        because: 'Admission loading must finish',
      ).isTrue();
      await ready.future;
      await tester.pump();
    } finally {
      service.removeListener(observeReady);
    }
  }

  Future<ProviderContainer> pumpHost(
    WidgetTester tester,
    _AdmissionHarness harness, {
    required ValueNotifier<int> videoBuilds,
    bool includeDock = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: _AdmissionOverlayHost(
            videoBuilds: videoBuilds,
            includeDock: includeDock,
          ),
        ),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SessionAdmissionOverlay)),
      listen: false,
    );
    final service = container.read(currentSessionProvider)!.admission;
    // Most scenarios start after durable admission data has loaded. Tests of
    // loading explicitly control the preferences future instead.
    if (harness._preferencesOverride == null) {
      await waitForAdmissionReady(tester, service);
    }
    return container;
  }

  Future<void> closeHost(WidgetTester tester) async {
    final overlay = find.byType(SessionAdmissionOverlay);
    if (overlay.evaluate().isNotEmpty) {
      final container = ProviderScope.containerOf(
        tester.element(overlay),
        listen: false,
      );
      await tester.runAsync(
        () => container.read(currentSessionProvider)!.admission.close(),
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
  }

  Future<void> seedDeclined(
    _AdmissionPreferences preferences,
    String identity,
  ) async {
    final container = ProviderContainer(
      overrides: [
        sessionAdmissionPreferencesProvider.overrideWith(
          (ref) async => preferences,
        ),
      ],
    );
    try {
      final provider = declinedSessionParticipantsProvider('session', 'keeper');
      await container.read(provider.future);
      await container.read(provider.notifier).decline(identity);
    } finally {
      container.dispose();
    }
  }

  Future<KeeperAdmissionRosterStore> seedRoster(
    _AdmissionPreferences preferences, {
    required Iterable<String> members,
    required int revision,
    Iterable<String> awaitingReadiness = const [],
  }) async {
    final container = ProviderContainer(
      overrides: [
        sessionAdmissionPreferencesProvider.overrideWith(
          (ref) async => preferences,
        ),
      ],
    );
    try {
      final provider = keeperAdmissionRosterProvider('session', 'keeper');
      final store = await container.read(provider.future);
      store.replace(members, revision, awaitingReadiness: awaitingReadiness);
      await container.read(provider.notifier).persist();
      return store;
    } finally {
      container.dispose();
    }
  }

  void setViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
  }

  Future<void> openStartConfirmation(
    WidgetTester tester,
    Future<bool> Function() onStart,
  ) async {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
    showDialog<void>(
      context: navigator.context,
      useRootNavigator: false,
      builder: (_) => SessionStartConfirmationDialog(onStart: onStart),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Keeper reconciles an unknown removal through verified recovery without resending it',
    (tester) async {
      setupAppConfig();
      final preferences = _AdmissionPreferences();
      await seedRoster(preferences, members: ['guest'], revision: 1);
      final harness = _AdmissionHarness(preferences: preferences);
      final videoBuilds = ValueNotifier(0);
      addTearDown(videoBuilds.dispose);
      setViewport(tester, const Size(390, 844));
      addTearDown(tester.view.reset);
      final container = await pumpHost(
        tester,
        harness,
        videoBuilds: videoBuilds,
      );
      final service = container.read(currentSessionProvider)!.admission;
      await container.read(
        keeperAdmissionRosterProvider('session', 'keeper').future,
      );
      await container.read(
        declinedSessionParticipantsProvider('session', 'keeper').future,
      );
      service.sync();
      await service.synchronized;
      final backend = _RemovalBackend()
        ..action = () async => throw TimeoutException('outcome unavailable');
      final moderation = moderationFor(harness, service, backend);
      await check(
        moderation.removeParticipant('guest'),
      ).throws<SessionCommandException>();
      await check(moderation.removeParticipant('guest')).throws<StateError>();
      check(backend.calls).equals(1);
      container
          .read(sessionPresentationProvider.notifier)
          .openPanel(SessionPanel.admission);
      await tester.pumpAndSettle();
      check(service.admittedIdentities.contains('guest')).isFalse();
      await tester.tap(find.text('Verified guest was not removed'));
      await tester.pumpAndSettle();
      check(service.admittedIdentities.contains('guest')).isFalse();
      await tester.tap(find.text('Confirm verified outcome'));
      await tester.pumpAndSettle();
      check(service.admittedIdentities).contains('guest');
      check(harness.mediaRecipients.last).contains('guest');
      check(backend.calls).equals(1);
      check(find.text('Verified guest was not removed').evaluate()).isEmpty();
      container.read(sessionPresentationProvider.notifier).closePanel();
      await tester.pumpAndSettle();
      await closeHost(tester);
      await tester.pump();
    },
    // Same third-party auto_size_text notification banner as the existing
    // error-notification tests below; Totem-owned hosts are unmounted above.
    experimentalLeakTesting: LeakTesting.settings.withIgnored(
      classes: <String>['TextPainter'],
    ),
  );

  testWidgets('session descendants observe live admission requests', (
    tester,
  ) async {
    final harness = _AdmissionHarness();
    final videoBuilds = ValueNotifier(0);
    addTearDown(videoBuilds.dispose);
    await pumpHost(tester, harness, videoBuilds: videoBuilds);
    await tester.pump();
    await harness.sendRequest(harness.request('first', name: 'First'));
    await tester.pump();

    tester
        .state<NavigatorState>(find.byType(Navigator).last)
        .push<void>(
          MaterialPageRoute<void>(
            builder: (context) {
              final scope = SessionAdmissionScope.maybeOf(context);
              return Text(
                scope?.requests
                        .map((request) => request.displayName)
                        .join(', ') ??
                    'No scope',
              );
            },
          ),
        );
    await tester.pumpAndSettle();
    check(find.text('First').evaluate()).length.equals(1);

    await harness.sendRequest(
      harness.request('second', sender: 'other', name: 'Second'),
    );
    await tester.pump();
    check(find.text('First, Second').evaluate()).length.equals(1);

    await closeHost(tester);
    await tester.pump();
  });

  testWidgets('admit all finishes sending approvals before starting', (
    tester,
  ) async {
    final harness = _AdmissionHarness();
    final videoBuilds = ValueNotifier(0);
    addTearDown(videoBuilds.dispose);
    await pumpHost(tester, harness, videoBuilds: videoBuilds);
    await tester.pump();
    await harness.sendRequest(harness.request('first'));
    await harness.sendRequest(harness.request('second', sender: 'other'));
    await tester.pump();

    final gate = Completer<void>();
    harness.afterSend = (packet) async {
      if (packet is AdmissionDecision && packet.id == 'first') {
        await gate.future;
      }
    };
    var starts = 0;
    final startGate = Completer<bool>();
    await openStartConfirmation(tester, () async {
      starts++;
      return await startGate.future;
    });
    await tester.tap(find.text('Admit all and start'));
    await tester.pump();
    check(starts).equals(0);
    check(harness.sent.whereType<AdmissionDecision>()).length.equals(1);
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();
    check(find.text('Something Went Wrong').evaluate()).isEmpty();
    check(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
    ).isNull();
    check(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Start without admitting'),
          )
          .onPressed,
    ).isNull();
    check(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Cancel'))
          .onPressed,
    ).isNull();
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Start without admitting'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pump();
    check(starts).equals(0);
    check(harness.sent.whereType<AdmissionDecision>()).length.equals(1);
    gate.complete();
    await tester.pump();
    await tester.pump();
    check(
      harness.sent.whereType<AdmissionDecision>().where((d) => d.approved),
    ).length.equals(2);
    check(starts).equals(1);
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();
    check(find.text('Something Went Wrong').evaluate()).isEmpty();
    check(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Cancel'))
          .onPressed,
    ).isNull();
    check(starts).equals(1);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
    check(SessionAdmissionScope.maybeOf(navigator.context)!.requests).isEmpty();
    check(
      tester
          .widget<ConfirmationDialog>(find.byType(ConfirmationDialog))
          .confirmButtonText,
    ).equals('Admit all and start');
    startGate.complete(true);
    await tester.pumpAndSettle();
    check(find.text('Admit all and start').evaluate()).isEmpty();
    await closeHost(tester);
    await tester.pump();
  });

  testWidgets(
    'admit all reports an admission already in progress without starting',
    (tester) async {
      setupAppConfig();
      silenceLogger();
      final harness = _AdmissionHarness();
      final videoBuilds = ValueNotifier(0);
      addTearDown(videoBuilds.dispose);
      await pumpHost(tester, harness, videoBuilds: videoBuilds);
      final request = harness.request('first');
      await harness.sendRequest(request);
      await tester.pump();
      final gate = Completer<void>();
      harness.afterSend = (packet) async {
        if (packet is AdmissionDecision) await gate.future;
      };
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      );
      final decision = SessionAdmissionScope.maybeOf(
        navigator.context,
      )!.onDecision(request, true);
      await tester.pump();
      var starts = 0;
      await openStartConfirmation(tester, () async {
        starts++;
        return true;
      });
      await tester.tap(find.text('Admit all and start'));
      await tester.pump();
      await tester.pump();
      check(find.text('Admission in progress').evaluate()).length.equals(1);
      check(
        find
            .text(
              'Wait for the current admission decision to finish, then try again.',
            )
            .evaluate(),
      ).length.equals(1);
      check(starts).equals(0);
      check(
        harness.sent.whereType<AdmissionDecision>().where((d) => d.approved),
      ).length.equals(1);
      gate.complete();
      await decision;
      await closeHost(tester);
      await tester.pump();
      await tester.idle();
    },
    // auto_size_text's notification banner does not dispose its TextPainters.
    experimentalLeakTesting: LeakTesting.settings.withIgnored(
      classes: <String>['TextPainter'],
    ),
  );

  testWidgets(
    'new arrivals prevent starting until the remaining queue is admitted',
    (tester) async {
      setupAppConfig();
      silenceLogger();
      final harness = _AdmissionHarness();
      final videoBuilds = ValueNotifier(0);
      addTearDown(videoBuilds.dispose);
      await pumpHost(tester, harness, videoBuilds: videoBuilds);
      await harness.sendRequest(harness.request('first'));
      await tester.pump();
      final gate = Completer<void>();
      harness.afterSend = (packet) async {
        if (packet is AdmissionDecision && packet.id == 'first') {
          await gate.future;
        }
      };
      var starts = 0;
      await openStartConfirmation(tester, () async {
        starts++;
        return true;
      });
      await tester.tap(find.text('Admit all and start'));
      await tester.pump();
      await harness.sendRequest(harness.request('second', sender: 'other'));
      await tester.pump();
      gate.complete();
      await tester.pump();
      await tester.pump();
      check(find.text('New participants arrived').evaluate()).length.equals(1);
      check(
        find
            .text('Review the waiting room and try again before starting.')
            .evaluate(),
      ).length.equals(1);
      check(
        find
            .text(
              'You have 1 participant waiting. Would you like to let them in before starting?',
            )
            .evaluate(),
      ).length.equals(1);
      check(starts).equals(0);
      check(
        harness.sent.whereType<AdmissionDecision>().where((d) => d.approved),
      ).length.equals(1);
      await tester.tap(find.text('Admit all and start'));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      check(
        harness.sent
            .whereType<AdmissionDecision>()
            .where((d) => d.approved)
            .map((d) => d.id)
            .toList(),
      ).deepEquals(['first', 'second']);
      check(starts).equals(1);
      await closeHost(tester);
      await tester.pump();
      await tester.idle();
    },
    // auto_size_text's notification banner does not dispose its TextPainters.
    experimentalLeakTesting: LeakTesting.settings.withIgnored(
      classes: <String>['TextPainter'],
    ),
  );

  testWidgets('start without admitting stays busy until start completes', (
    tester,
  ) async {
    final harness = _AdmissionHarness();
    final videoBuilds = ValueNotifier(0);
    addTearDown(videoBuilds.dispose);
    await pumpHost(tester, harness, videoBuilds: videoBuilds);
    await tester.pump();
    await harness.sendRequest(harness.request('waiting'));
    await tester.pump();
    final gate = Completer<bool>();
    var starts = 0;
    await openStartConfirmation(tester, () {
      starts++;
      return gate.future;
    });
    await tester.tap(find.text('Start without admitting'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();
    check(find.text('Something Went Wrong').evaluate()).isEmpty();
    check(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Admit all and start'),
          )
          .onPressed,
    ).isNull();
    check(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Cancel'))
          .onPressed,
    ).isNull();
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Admit all and start'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pump();
    check(starts).equals(1);
    check(harness.sent.whereType<AdmissionDecision>()).isEmpty();
    gate.complete(true);
    await tester.pumpAndSettle();
    check(starts).equals(1);
    check(find.text('Start without admitting').evaluate()).isEmpty();
    await closeHost(tester);
    await tester.pump();
  });

  testWidgets(
    'start without admitting leaves the queue intact and retries a failed start',
    (tester) async {
      final harness = _AdmissionHarness();
      final videoBuilds = ValueNotifier(0);
      addTearDown(videoBuilds.dispose);
      await pumpHost(tester, harness, videoBuilds: videoBuilds);
      await tester.pump();
      await harness.sendRequest(harness.request('waiting'));
      await tester.pump();
      var starts = 0;
      await openStartConfirmation(tester, () async => ++starts > 1);
      await tester.tap(find.text('Start without admitting'));
      await tester.pump();
      check(starts).equals(1);
      check(find.text('Start without admitting').evaluate()).length.equals(1);
      check(harness.sent.whereType<AdmissionDecision>()).isEmpty();
      await tester.tap(find.text('Start without admitting'));
      await tester.pumpAndSettle();
      check(starts).equals(2);
      check(find.text('Start without admitting').evaluate()).isEmpty();
      check(harness.sent.whereType<AdmissionDecision>()).isEmpty();
      await openStartConfirmation(tester, () async => true);
      check(
        find
            .text(
              'You have 1 participant waiting. Would you like to let them in before starting?',
            )
            .evaluate(),
      ).length.equals(1);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await closeHost(tester);
      await tester.pump();
    },
  );

  testWidgets('cancel leaves pending requests untouched without starting', (
    tester,
  ) async {
    final harness = _AdmissionHarness();
    final videoBuilds = ValueNotifier(0);
    addTearDown(videoBuilds.dispose);
    await pumpHost(tester, harness, videoBuilds: videoBuilds);
    await tester.pump();
    await harness.sendRequest(harness.request('waiting'));
    await tester.pump();
    var starts = 0;
    await openStartConfirmation(tester, () async {
      starts++;
      return true;
    });
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    check(starts).equals(0);
    check(harness.sent.whereType<AdmissionDecision>()).isEmpty();
    await openStartConfirmation(tester, () async => true);
    check(find.text('Start without admitting').evaluate()).length.equals(1);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await closeHost(tester);
    await tester.pump();
  });

  testWidgets(
    'start confirmation follows live queue count and falls back when empty',
    (tester) async {
      final harness = _AdmissionHarness();
      final videoBuilds = ValueNotifier(0);
      addTearDown(videoBuilds.dispose);
      await pumpHost(tester, harness, videoBuilds: videoBuilds);
      await tester.pump();
      final first = harness.request('first');
      await harness.sendRequest(first);
      await tester.pump();
      await openStartConfirmation(tester, () async => true);
      check(
        find
            .text(
              'You have 1 participant waiting. Would you like to let them in before starting?',
            )
            .evaluate(),
      ).length.equals(1);
      final second = harness.request('second', sender: 'other');
      await harness.sendRequest(second);
      await tester.pump();
      check(
        find
            .text(
              'You have 2 participants waiting. Would you like to let them in before starting?',
            )
            .evaluate(),
      ).length.equals(1);
      for (final request in [first, second]) {
        await harness.sendPacket(
          AdmissionCancel(
            id: request.id,
            senderIdentity: request.senderIdentity,
            recipientIdentity: request.recipientIdentity,
            expiresAt: request.expiresAt,
          ),
        );
      }
      await tester.pump();
      check(
        find.text('Are you sure you want to start the session?').evaluate(),
      ).length.equals(1);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Start session'));
      await tester.pumpAndSettle();
      check(
        find.text('Are you sure you want to start the session?').evaluate(),
      ).isEmpty();
      await closeHost(tester);
      await tester.pump();
    },
  );

  testWidgets(
    'start confirmation without an admission scope reports a failed start and closes after retry',
    (tester) async {
      silenceLogger();
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const ActionFeedbackHost(child: SizedBox()),
          ),
        ),
      );
      var starts = 0;
      showDialog<void>(
        context: navigatorKey.currentContext!,
        builder: (_) => SessionStartConfirmationDialog(
          onStart: () async {
            starts++;
            if (starts == 1) throw AppNetworkException.noConnection();
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      check(
        find.text('Are you sure you want to start the session?').evaluate(),
      ).length.equals(1);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Start session'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      check(starts).equals(1);
      check(find.text("Couldn't start the session").evaluate()).isNotEmpty();
      check(
        find
            .text('Everyone is still in the waiting room. Please try again.')
            .evaluate(),
      ).isNotEmpty();
      // The dialog stays open, so confirming again is the retry.
      check(
        find.text('Are you sure you want to start the session?').evaluate(),
      ).length.equals(1);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Start session'));
      await tester.pumpAndSettle();
      check(starts).equals(2);
      check(
        find.text('Are you sure you want to start the session?').evaluate(),
      ).isEmpty();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
    // auto_size_text's notification banner does not dispose its TextPainters.
    experimentalLeakTesting: LeakTesting.settings.withIgnored(
      classes: <String>['TextPainter'],
    ),
  );

  testWidgets(
    'failed admission keeps confirmation open and allows retry',
    (tester) async {
      setupAppConfig();
      silenceLogger();
      final harness = _AdmissionHarness();
      final videoBuilds = ValueNotifier(0);
      addTearDown(videoBuilds.dispose);
      await pumpHost(tester, harness, videoBuilds: videoBuilds);
      await tester.pump();
      await harness.sendRequest(harness.request('waiting'));
      await tester.pump();
      harness.afterSend = (packet) async {
        if (packet is AdmissionDecision) throw StateError('offline');
      };
      var starts = 0;
      await openStartConfirmation(tester, () async {
        starts++;
        return true;
      });
      await tester.tap(find.text('Admit all and start'));
      await tester.pump();
      await tester.pump();
      check(starts).equals(0);
      check(find.text('Admit all and start').evaluate()).length.equals(1);

      harness.afterSend = null;
      harness.sent.clear();
      await tester.tap(find.text('Admit all and start'));
      await tester.pump();
      await tester.pumpAndSettle();
      check(
        harness.sent.whereType<AdmissionDecision>().where((d) => d.approved),
      ).length.equals(1);
      check(starts).equals(1);
      check(find.text('Admit all and start').evaluate()).isEmpty();
      await closeHost(tester);
      await tester.pump();
      await tester.idle();
    },
    // auto_size_text's notification banner does not dispose its TextPainters.
    experimentalLeakTesting: LeakTesting.settings.withIgnored(
      classes: <String>['TextPainter'],
    ),
  );

  testWidgets('fails closed until persisted declines initialize', (
    tester,
  ) async {
    final preferencesReady = Completer<SessionAdmissionPreferences>();
    final preferences = _AdmissionPreferences();
    await seedDeclined(preferences, 'guest');
    final harness = _AdmissionHarness(
      preferences: preferences,
      preferencesOverride: (ref) => preferencesReady.future,
    );
    harness.room.remotes['guest'] = _RemoteParticipant('guest');
    final videoBuilds = ValueNotifier(0);
    addTearDown(videoBuilds.dispose);

    final container = await pumpHost(tester, harness, videoBuilds: videoBuilds);
    container.read(sessionAdmissionSettingsProvider.notifier).setEnabled(false);
    await harness.sendRequest(harness.request('before-preferences'));
    await tester.pump();

    check(harness.sent).isEmpty();
    check(harness.mediaRecipients).isEmpty();
    check(find.byType(SessionWaitingQueueButton).evaluate()).isEmpty();

    preferencesReady.complete(harness.preferences);
    await waitForAdmissionReady(
      tester,
      container.read(currentSessionProvider)!.admission,
    );

    await harness.sendRequest(harness.request('blocked-after-preferences'));
    await tester.pump();
    await tester.pump();

    final decisions = harness.sent.whereType<AdmissionDecision>().toList();
    check(decisions).length.equals(1);
    check(decisions.single.id).equals('blocked-after-preferences');
    check(decisions.single.approved).isFalse();

    await tester.pump(const Duration(minutes: 5));
    await closeHost(tester);
    await tester.pump();
    await tester.idle();
  });

  for (final corruptStores in [
    {'roster'},
    {'declined'},
    {'roster', 'declined'},
  ]) {
    testWidgets('reset restores admission with corrupt $corruptStores', (
      tester,
    ) async {
      final preferences = _AdmissionPreferences();
      await seedDeclined(preferences, 'blocked');
      final declinedKey = preferences.values.keys.single;
      await seedRoster(preferences, members: ['member'], revision: 2);
      final rosterKey = preferences.values.keys.singleWhere(
        (key) => key != declinedKey,
      );
      preferences.values['unrelated'] = 'keep';
      final original = Map<String, String>.of(preferences.values);
      if (corruptStores.contains('declined')) {
        preferences.values[declinedKey] = '{';
      }
      if (corruptStores.contains('roster')) {
        preferences.values[rosterKey] = '{';
      }
      final beforeReset = Map<String, String>.of(preferences.values);
      final harness = _AdmissionHarness(preferences: preferences);
      final videoBuilds = ValueNotifier(0);
      addTearDown(videoBuilds.dispose);

      final container = await pumpHost(
        tester,
        harness,
        videoBuilds: videoBuilds,
      );
      await tester.pump();
      await tester.tap(find.byType(SessionWaitingQueueButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset admission data'));
      await tester.pumpAndSettle();

      check(find.byType(ConfirmationDialog).evaluate()).length.equals(1);
      check(
        find
            .descendant(
              of: find.byType(ConfirmationDialog),
              matching: find.textContaining(
                RegExp('lost|remov|delet|clear', caseSensitive: false),
              ),
            )
            .evaluate(),
      ).isNotEmpty();
      check(preferences.values).deepEquals(beforeReset);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      check(preferences.values).deepEquals(beforeReset);
      check(find.byType(ConfirmationDialog).evaluate()).isEmpty();

      await tester.tap(find.text('Reset admission data'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ConfirmationDialog),
          matching: find.text('Reset admission data'),
        ),
      );
      await tester.pumpAndSettle();
      check(preferences.values[declinedKey]).equals(
        corruptStores.contains('declined') ? null : original[declinedKey],
      );
      check(
        preferences.values[rosterKey],
      ).equals(corruptStores.contains('roster') ? null : original[rosterKey]);
      check(preferences.values['unrelated']).equals('keep');
      final declined = await container.read(
        declinedSessionParticipantsProvider('session', 'keeper').future,
      );
      final roster = await container.read(
        keeperAdmissionRosterProvider('session', 'keeper').future,
      );
      check(
        declined.contains('blocked'),
      ).equals(!corruptStores.contains('declined'));
      check(
        roster.members.contains('member'),
      ).equals(!corruptStores.contains('roster'));
      check(find.text('Retry').evaluate()).isEmpty();
      check(find.text('Reset admission data').evaluate()).isEmpty();

      await closeHost(tester);
      await tester.pump();
      await tester.idle();
    });
  }

  testWidgets('keeper can explicitly reset a corrupt removal journal', (
    tester,
  ) async {
    setupAppConfig();
    final preferences = _AdmissionPreferences();
    await seedDeclined(preferences, 'blocked');
    await seedRoster(preferences, members: ['member'], revision: 2);
    preferences.values[removalJournalKey] = '{';
    final harness = _AdmissionHarness(
      preferences: preferences,
      preferencesOverride: (_) async => preferences,
    );
    final videoBuilds = ValueNotifier(0);
    addTearDown(videoBuilds.dispose);

    final container = await pumpHost(tester, harness, videoBuilds: videoBuilds);
    await tester.tap(find.byType(SessionWaitingQueueButton));
    await tester.pumpAndSettle();
    check(find.text('Reset removal recovery').evaluate()).length.equals(1);

    await tester.tap(find.text('Reset removal recovery'));
    await tester.pumpAndSettle();
    check(find.byType(ConfirmationDialog).evaluate()).length.equals(1);
    check(find.textContaining('journal is unreadable').evaluate()).isNotEmpty();
    await tester.tap(
      find.descendant(
        of: find.byType(ConfirmationDialog),
        matching: find.text('Reset removal recovery'),
      ),
    );
    await tester.pumpAndSettle();

    final service = container.read(currentSessionProvider)!.admission;
    check(preferences.values.containsKey(removalJournalKey)).isFalse();
    check(service.hasCorruptRemovalJournal).isFalse();
    check(service.keeperController).isNotNull();
    check(find.text('Retry').evaluate()).isEmpty();

    await closeHost(tester);
    await tester.pump();
    await tester.idle();
  });

  testWidgets('ordinary read errors offer retry without resetting data', (
    tester,
  ) async {
    final preferences = _AdmissionPreferences();
    await seedDeclined(preferences, 'blocked');
    await seedRoster(preferences, members: ['member'], revision: 2);
    final original = Map<String, String>.of(preferences.values);
    preferences.readError = StateError('unavailable');
    final harness = _AdmissionHarness(preferences: preferences);
    final videoBuilds = ValueNotifier(0);
    addTearDown(videoBuilds.dispose);

    final container = await pumpHost(tester, harness, videoBuilds: videoBuilds);
    await tester.pump();
    await tester.tap(find.byType(SessionWaitingQueueButton));
    await tester.pumpAndSettle();
    check(find.text('Retry').evaluate()).length.equals(1);
    check(find.text('Reset admission data').evaluate()).isEmpty();
    preferences.readError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    check(preferences.values).deepEquals(original);
    final declined = await container.read(
      declinedSessionParticipantsProvider('session', 'keeper').future,
    );
    final roster = await container.read(
      keeperAdmissionRosterProvider('session', 'keeper').future,
    );
    check(declined).contains('blocked');
    check(roster.members).contains('member');
    check(find.text('Retry').evaluate()).isEmpty();

    await closeHost(tester);
    await tester.pump();
    await tester.idle();
  });

  testWidgets('does not advertise an empty roster when persistence fails', (
    tester,
  ) async {
    final harness = _AdmissionHarness(
      preferences: _AdmissionPreferences(readError: StateError('unavailable')),
    );
    harness.room.remotes['guest'] = _RemoteParticipant('guest');
    final videoBuilds = ValueNotifier(0);
    addTearDown(videoBuilds.dispose);

    await pumpHost(tester, harness, videoBuilds: videoBuilds);
    await tester.pump();
    await tester.pump();

    check(harness.sent).isEmpty();
    check(harness.mediaRecipients.expand((recipients) => recipients)).isEmpty();

    await closeHost(tester);
    await tester.pump();
    await tester.idle();
  });

  testWidgets(
    'persists roster authority but not queue-only admission changes',
    (tester) async {
      final preferences = _AdmissionPreferences();
      final harness = _AdmissionHarness(preferences: preferences);
      final videoBuilds = ValueNotifier(0);
      addTearDown(videoBuilds.dispose);

      final container = await pumpHost(
        tester,
        harness,
        videoBuilds: videoBuilds,
      );
      container
          .read(sessionAdmissionSettingsProvider.notifier)
          .setEnabled(false);
      await tester.pump();

      final request = harness.request('admit');
      await harness.sendRequest(request);
      await tester.pump();
      await tester.pump();
      check(preferences.writeCount).equals(0);

      await harness.sendPacket(AdmissionProtocol.joined(request));
      await tester.pump();
      await tester.pump();
      check(preferences.writeCount).equals(1);

      await harness.sendRequest(harness.request('ready-again'));
      await tester.pump();
      await tester.pump();
      check(preferences.writeCount).equals(2);

      await closeHost(tester);
      await tester.pump();
      await tester.idle();

      final restored = ProviderContainer(
        overrides: [
          sessionAdmissionPreferencesProvider.overrideWith(
            (ref) async => preferences,
          ),
        ],
      );
      addTearDown(restored.dispose);
      final roster = await restored.read(
        keeperAdmissionRosterProvider('session', 'keeper').future,
      );
      check(roster.revision).equals(2);
      check(roster.members).contains('guest');
      check(roster.awaitingReadiness).contains('guest');
      restored.dispose();
      // Flush Riverpod's scheduled auto-disposal after the final read.
      await tester.pump();
    },
  );

  test('ending a Session removes its local admission data', () async {
    final preferences = _AdmissionPreferences();
    await seedDeclined(preferences, 'guest');
    await seedRoster(preferences, members: ['guest'], revision: 2);
    final (harness, _, service) = await removalSession(preferences);
    check(preferences.values).length.equals(2);

    endSession(harness);
    service.sync();
    await service.synchronized;

    check(preferences.values).isEmpty();
    check(service.keeperController).isNull();
    await service.close();
    check(preferences.values).isEmpty();
  });

  testWidgets(
    'restores admitted media-off members across a fresh ProviderScope',
    (tester) async {
      final preferences = _AdmissionPreferences();
      final savedRoster = await seedRoster(
        preferences,
        members: ['guest', 'silent'],
        revision: 7,
      );
      final firstHarness = _AdmissionHarness(preferences: preferences);
      final videoBuilds = ValueNotifier(0);
      addTearDown(videoBuilds.dispose);

      await pumpHost(tester, firstHarness, videoBuilds: videoBuilds);
      await tester.pump();
      await closeHost(tester);
      await tester.pump();
      await tester.idle();

      final restoredHarness = _AdmissionHarness(preferences: preferences);
      restoredHarness.room.remotes['guest'] = _RemoteParticipant('guest');
      restoredHarness.room.remotes['silent'] = _RemoteParticipant('silent');
      final container = await pumpHost(
        tester,
        restoredHarness,
        videoBuilds: videoBuilds,
      );
      await tester.pump();

      final admitted = container.read(
        admittedSessionParticipantIdentitiesProvider,
      );
      check(admitted).contains('guest');
      check(admitted).contains('silent');
      check(
        restoredHarness.mediaRecipients.last,
      ).deepEquals({'guest', 'silent'});

      restoredHarness.sent.clear();
      final request = AdmissionRosterRequest(
        id: 'restore-roster',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: restoredHarness.expiration(),
        sessionIdentity: 'session',
      );
      await restoredHarness.sendPacket(request);
      await tester.pump();

      final snapshot = restoredHarness.sent
          .whereType<AdmissionRosterSnapshot>()
          .single;
      check(snapshot.requestId).equals(request.id);
      check(snapshot.keeperGeneration).equals(savedRoster.keeperGeneration);
      check(snapshot.revision).equals(7);
      check(snapshot.members).deepEquals(['guest', 'silent']);

      await closeHost(tester);
      await tester.pump();
      await tester.idle();
    },
  );

  testWidgets('removed admitted guest must request approval again', (
    tester,
  ) async {
    final preferences = _AdmissionPreferences();
    await seedRoster(preferences, members: ['guest', 'silent'], revision: 7);
    final harness = _AdmissionHarness(preferences: preferences);
    harness.room.remotes['guest'] = _RemoteParticipant('guest');
    harness.room.remotes['silent'] = _RemoteParticipant('silent');
    final videoBuilds = ValueNotifier(0);
    addTearDown(videoBuilds.dispose);

    final container = ProviderContainer(overrides: harness.overrides);
    addTearDown(container.dispose);
    final subscription = container.listen(
      sessionKeeperControllerProvider(harness.session),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: _AdmissionOverlayHost(videoBuilds: videoBuilds),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    check(harness.mediaRecipients.last).deepEquals({'guest', 'silent'});

    await harness.session.admission.revokeRemovedParticipant('guest');
    await tester.pump();
    check(
      container.read(admittedSessionParticipantIdentitiesProvider),
    ).deepEquals({'keeper', 'silent'});
    check(harness.mediaRecipients.last).deepEquals({'silent'});

    final restored = ProviderContainer(
      overrides: [
        sessionAdmissionPreferencesProvider.overrideWith(
          (ref) async => preferences,
        ),
      ],
    );
    addTearDown(restored.dispose);
    final roster = await restored.read(
      keeperAdmissionRosterProvider('session', 'keeper').future,
    );
    check(roster.members).deepEquals({'silent'});
    check(roster.revision).equals(8);

    harness.sent.clear();
    await harness.sendRequest(harness.request('rejoin'));
    await tester.pump();
    await tester.pump();
    check(find.byType(SessionWaitingQueueButton).evaluate()).length.equals(1);
    check(harness.sent.whereType<AdmissionDecision>()).isEmpty();

    // Temporarily unmount only the presentation; the retained session still
    // owns admission and must accept requests when the host returns.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final controller = harness.session.admission.keeperController;
    check(controller).isNotNull();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: _AdmissionOverlayHost(videoBuilds: videoBuilds),
        ),
      ),
    );
    await tester.pump();
    check(
      identical(harness.session.admission.keeperController, controller),
    ).isTrue();
    check(harness.room.transportCreations).equals(1);
    await closeHost(tester);
    await tester.pump();

    await tester.idle();
  });

  testWidgets('does not restore pending or awaiting-readiness applicants', (
    tester,
  ) async {
    final preferences = _AdmissionPreferences();
    final savedRoster = await seedRoster(
      preferences,
      members: ['guest'],
      revision: 3,
      awaitingReadiness: ['guest'],
    );
    final pendingHarness = _AdmissionHarness(preferences: preferences);
    final videoBuilds = ValueNotifier(0);
    addTearDown(videoBuilds.dispose);

    await pumpHost(tester, pendingHarness, videoBuilds: videoBuilds);
    await pendingHarness.sendRequest(pendingHarness.request('pending'));
    await tester.pump();
    await tester.pump();
    check(find.byType(SessionWaitingQueueButton).evaluate()).length.equals(1);

    await closeHost(tester);
    await tester.pump();
    await tester.idle();

    final restoredHarness = _AdmissionHarness(preferences: preferences);
    final container = await pumpHost(
      tester,
      restoredHarness,
      videoBuilds: videoBuilds,
    );
    await tester.pump();

    check(find.byType(SessionWaitingQueueButton).evaluate()).isEmpty();
    check(
      container
          .read(admittedSessionParticipantIdentitiesProvider)
          .contains('guest'),
    ).isFalse();
    check(restoredHarness.mediaRecipients.last).isEmpty();

    final request = AdmissionRosterRequest(
      id: 'awaiting-readiness',
      senderIdentity: 'guest',
      recipientIdentity: 'keeper',
      expiresAt: restoredHarness.expiration(),
      sessionIdentity: 'session',
    );
    await restoredHarness.sendPacket(request);
    await tester.pump();
    final snapshot = restoredHarness.sent
        .whereType<AdmissionRosterSnapshot>()
        .single;
    check(snapshot.keeperGeneration).equals(savedRoster.keeperGeneration);
    check(snapshot.revision).equals(3);
    check(snapshot.members).isEmpty();

    await closeHost(tester);
    await tester.pump();
    await tester.idle();
  });

  testWidgets(
    'shows live queue updates in a phone sheet above the toolbar without rebuilding video',
    (tester) async {
      setViewport(tester, const Size(400, 800));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = _AdmissionHarness();
      final videoBuilds = ValueNotifier(0);
      addTearDown(videoBuilds.dispose);

      await pumpHost(tester, harness, videoBuilds: videoBuilds);
      final initialVideoBuilds = videoBuilds.value;
      await harness.sendRequest(harness.request('one'));
      await tester.pump();
      await tester.pump();

      final queue = find.byType(SessionWaitingQueueButton);
      final toolbar = find.byKey(SessionActionBar.actionBarKey);
      check(queue.evaluate()).length.equals(1);
      check(
        tester.getRect(queue).bottom,
      ).isLessOrEqual(tester.getRect(toolbar).top);
      check(videoBuilds.value).equals(initialVideoBuilds);

      await tester.tap(queue);
      await tester.pumpAndSettle();
      check(find.byType(SessionAdmissionPanel).evaluate()).length.equals(1);

      await harness.sendRequest(harness.request('two', name: 'Second guest'));
      await tester.pump();
      await tester.pump();
      check(find.text('Second guest').evaluate()).length.equals(1);
      check(videoBuilds.value).equals(initialVideoBuilds);

      await tester.tap(find.byTooltip('Close admission'));
      await tester.pumpAndSettle();
      check(find.byType(SessionAdmissionPanel).evaluate()).isEmpty();
      check(find.byType(SessionWaitingQueueButton).evaluate()).length.equals(1);

      await tester.pump(const Duration(minutes: 5));
      await closeHost(tester);
      await tester.pump();
      await tester.idle();
    },
  );

  testWidgets(
    'opens the tablet drawer from the room navigator and closes on back',
    (tester) async {
      setViewport(tester, const Size(800, 900));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = _AdmissionHarness();
      final videoBuilds = ValueNotifier(0);
      addTearDown(videoBuilds.dispose);

      await pumpHost(tester, harness, videoBuilds: videoBuilds);
      await harness.sendRequest(harness.request('drawer'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(SessionWaitingQueueButton));
      await tester.pumpAndSettle();
      check(find.byType(SessionAdmissionPanel).evaluate()).length.equals(1);
      check(
        tester.getSize(find.byType(SessionAdmissionPanel)).width,
      ).equals(sessionSidePanelWidth);

      await tester
          .state<NavigatorState>(find.byType(Navigator).last)
          .maybePop();
      await tester.pumpAndSettle();
      check(find.byType(SessionAdmissionPanel).evaluate()).isEmpty();

      await tester.pump(const Duration(minutes: 5));
      await closeHost(tester);
      await tester.pump();
      await tester.idle();
    },
  );

  testWidgets(
    'closes admission when the dock no longer fits and keeps it closed on widening',
    (tester) async {
      setViewport(tester, const Size(1200, 900));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = _AdmissionHarness();
      final videoBuilds = ValueNotifier(0);
      addTearDown(videoBuilds.dispose);

      final container = await pumpHost(
        tester,
        harness,
        videoBuilds: videoBuilds,
        includeDock: true,
      );
      await harness.sendRequest(harness.request('resize'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(SessionWaitingQueueButton));
      await tester.pumpAndSettle();
      check(container.read(sessionAdmissionSelectedProvider)).isTrue();
      check(find.byType(SessionAdmissionPanel).evaluate()).length.equals(1);

      setViewport(tester, const Size(800, 900));
      await tester.pump();
      check(find.byType(DockedSessionSidePanel).evaluate()).isEmpty();
      await tester.pumpAndSettle();
      check(container.read(sessionAdmissionSelectedProvider)).isFalse();
      check(find.byType(SessionAdmissionPanel).evaluate()).isEmpty();

      setViewport(tester, const Size(1200, 900));
      await tester.pumpAndSettle();
      check(find.byType(SessionAdmissionPanel).evaluate()).isEmpty();
      check(container.read(sessionAdmissionSelectedProvider)).isFalse();

      await tester.pump(const Duration(minutes: 5));
      await closeHost(tester);
      await tester.pump();
      await tester.idle();
    },
  );

  testWidgets('admit all skips requests cancelled while deciding the batch', (
    tester,
  ) async {
    setViewport(tester, const Size(1200, 900));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = _AdmissionHarness();
    final videoBuilds = ValueNotifier(0);
    addTearDown(videoBuilds.dispose);

    await pumpHost(
      tester,
      harness,
      videoBuilds: videoBuilds,
      includeDock: true,
    );
    final first = harness.request('first', sender: 'alice', name: 'Alice');
    final second = harness.request(
      'second',
      sender: 'bob',
      name: 'Bob',
      expiresAt: first.expiresAt.add(const Duration(seconds: 1)),
    );
    await harness.sendRequest(first);
    await harness.sendRequest(second);
    harness.afterSend = (packet) async {
      if (packet is AdmissionDecision && packet.id == first.id) {
        await harness.sendPacket(
          AdmissionCancel(
            id: second.id,
            senderIdentity: second.senderIdentity,
            recipientIdentity: second.recipientIdentity,
            expiresAt: second.expiresAt,
          ),
        );
      }
    };
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(SessionWaitingQueueButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admit all'));
    await tester.pump();
    await tester.pump();

    final decisions = harness.sent.whereType<AdmissionDecision>().toList();
    check(decisions).length.equals(1);
    check(decisions.single.id).equals(first.id);

    await closeHost(tester);
    await tester.pump();
    await tester.idle();
  });

  testWidgets(
    'admit all shows one error notification when multiple sends fail',
    (tester) async {
      setViewport(tester, const Size(1200, 900));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      setupAppConfig();
      silenceLogger();
      final harness = _AdmissionHarness();
      final videoBuilds = ValueNotifier(0);
      addTearDown(videoBuilds.dispose);

      await pumpHost(
        tester,
        harness,
        videoBuilds: videoBuilds,
        includeDock: true,
      );
      final first = harness.request('first', sender: 'alice', name: 'Alice');
      final second = harness.request(
        'second',
        sender: 'bob',
        name: 'Bob',
        expiresAt: first.expiresAt.add(const Duration(seconds: 1)),
      );
      await harness.sendRequest(first);
      await harness.sendRequest(second);
      harness.afterSend = (packet) async {
        if (packet is AdmissionDecision) throw StateError('offline');
      };
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(SessionWaitingQueueButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Admit all'));
      await tester.pump();
      await tester.pump();

      check(harness.sent.whereType<AdmissionDecision>()).length.equals(2);
      check(
        find
            .descendant(
              of: find.byType(NotificationBanner),
              matching: find.text('Could not update the queue'),
            )
            .evaluate(),
      ).length.equals(1);

      await closeHost(tester);
      await tester.pump();
      await tester.idle();
    },
    // auto_size_text's notification banner does not dispose its TextPainters.
    experimentalLeakTesting: LeakTesting.settings.withIgnored(
      classes: <String>['TextPainter'],
    ),
  );

  testWidgets(
    'permanent decline ignores a request replaced while its dialog is open',
    (tester) async {
      setViewport(tester, const Size(1200, 900));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = _AdmissionHarness();
      final videoBuilds = ValueNotifier(0);
      addTearDown(videoBuilds.dispose);

      final container = await pumpHost(
        tester,
        harness,
        videoBuilds: videoBuilds,
        includeDock: true,
      );
      final declinedProvider = declinedSessionParticipantsProvider(
        'session',
        'keeper',
      );
      await container.read(declinedProvider.future);
      final oldRequest = harness.request('old');
      await harness.sendRequest(oldRequest);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(SessionWaitingQueueButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();

      final replacement = harness.request(
        'replacement',
        expiresAt: oldRequest.expiresAt.add(const Duration(seconds: 1)),
      );
      await harness.sendRequest(replacement);
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Decline Permanently'));
      await tester.pump();

      check(container.read(declinedProvider).requireValue).isEmpty();
      check(harness.sent.whereType<AdmissionDecision>()).isEmpty();

      await closeHost(tester);
      await tester.pump();
      await tester.idle();
    },
  );

  testWidgets(
    'docks beside the room and allows joining after permanent decline',
    (tester) async {
      setViewport(tester, const Size(1200, 900));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = _AdmissionHarness();
      final videoBuilds = ValueNotifier(0);
      addTearDown(videoBuilds.dispose);

      final container = await pumpHost(
        tester,
        harness,
        videoBuilds: videoBuilds,
        includeDock: true,
      );
      final request = harness.request('permanent');
      await harness.sendRequest(request);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(SessionWaitingQueueButton));
      await tester.pumpAndSettle();
      check(find.byType(SessionAdmissionPanel).evaluate()).length.equals(1);

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Decline Permanently'));
      await tester.pump();
      await tester.pump();

      check(
        harness.sent
            .whereType<AdmissionDecision>()
            .singleWhere((decision) => decision.id == request.id)
            .approved,
      ).isFalse();

      await container
          .read(
            declinedSessionParticipantsProvider('session', 'keeper').notifier,
          )
          .allow('guest');
      container
          .read(sessionAdmissionSettingsProvider.notifier)
          .setEnabled(false);
      await tester.pump();
      final allowedRequest = harness.request('allowed');
      await harness.sendRequest(allowedRequest);
      await tester.pump();
      await tester.pump();

      check(
        harness.sent
            .whereType<AdmissionDecision>()
            .singleWhere((decision) => decision.id == allowedRequest.id)
            .approved,
      ).isTrue();
      check(
        container
            .read(admittedSessionParticipantIdentitiesProvider)
            .contains('guest'),
      ).isFalse();

      await harness.room.listener.trigger(
        DataReceivedEvent(
          data: AdmissionProtocol.encode(
            AdmissionProtocol.joined(allowedRequest),
          ),
          participant: _RemoteParticipant('guest'),
          topic: AdmissionProtocol.topic,
        ),
      );
      await tester.pump();
      check(
        container
            .read(admittedSessionParticipantIdentitiesProvider)
            .contains('guest'),
      ).isTrue();

      await tester.pump(const Duration(minutes: 5));
      await closeHost(tester);
      await tester.pump();
      await tester.idle();
    },
  );
}
