import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/declined_session_participants.dart';
import 'package:totem_core/features/sessions/admission/keeper_admission_panel.dart';
import 'package:totem_core/features/sessions/admission/session_admission_overlay.dart';
import 'package:totem_core/features/sessions/admission/session_admission_settings.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart'
    as session_state;
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/features/sessions/widgets/session_side_panel.dart';
import 'package:totem_core/features/sessions/widgets/session_waiting_queue_button.dart';

import '../livekit_mocks.dart';
import '../session_test_mocks.dart';

class _AdmissionPreferences implements SessionAdmissionPreferences {
  _AdmissionPreferences({this.preloadedValue});

  final String? preloadedValue;
  final values = <String, String>{};

  @override
  String? getString(String key) => values[key] ?? preloadedValue;

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }
}

class _AdmissionRoom extends FakeRoom {
  _AdmissionRoom(super.participant);

  final listener = _AdmissionEvents();

  @override
  EventsListener<RoomEvent> createListener({bool synchronized = true}) =>
      listener;
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
    final admissionOpen = ref.watch(sessionAdmissionOpenProvider);
    return SessionAdmissionOverlay(
      sessionSlug: 'session',
      child: RoomBackground(
        status: RoomStatus.active,
        child: Row(
          children: [
            Expanded(
              child: Navigator(
                key: const Key('room-navigator'),
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => Column(
                    children: [
                      Expanded(child: _VideoPlaceholder(videoBuilds)),
                      SessionAdmissionQueueControl(
                        child: SizedBox(
                          key: SessionActionBar.actionBarKey,
                          height: 64,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (includeDock && shouldDockSessionSidePanel(context))
              DockedSessionSidePanel(
                open: admissionOpen,
                child: admissionOpen
                    ? const SessionAdmissionPanel(docked: true)
                    : null,
              ),
          ],
        ),
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
        now: DateTime.now(),
      );
      if (packet != null) sent.add(packet);
    });
    room = _AdmissionRoom(participant);
    session = _SessionController();
    state = MockSessionRoomState();
    when(() => session.room).thenReturn(room);
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

  final _AdmissionPreferences preferences;
  final sent = <AdmissionPacket>[];
  late final _AdmissionRoom room;
  late final _SessionController session;
  late final MockSessionRoomState state;
  late final Future<SessionAdmissionPreferences> Function(Ref ref)?
  _preferencesOverride;

  List<Override> get overrides => [
    sessionAdmissionPreferencesProvider.overrideWith(
      _preferencesOverride ?? (ref) async => preferences,
    ),
    currentSessionProvider.overrideWith((ref) => session),
    currentSessionStateProvider.overrideWithValue(state),
    currentSessionEventProvider.overrideWith((ref) => null),
    isCurrentUserKeeperProvider.overrideWith((ref) => true),
    userProfileProvider('guest').overrideWith(
      (ref) => PublicUserSchema(
        profileAvatarType: ProfileAvatarTypeEnum.td,
        dateCreated: DateTime(2024),
      ),
    ),
  ];

  AdmissionRequest request(String id, {String name = 'Guest'}) =>
      AdmissionRequest(
        id: id,
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        displayName: name,
      );

  Future<void> sendRequest(AdmissionRequest request) => room.listener.trigger(
    DataReceivedEvent(
      data: AdmissionProtocol.encode(request),
      participant: _RemoteParticipant('guest'),
      topic: AdmissionProtocol.topic,
    ),
  );
}

void main() {
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
    return ProviderScope.containerOf(
      tester.element(find.byType(SessionAdmissionOverlay)),
      listen: false,
    );
  }

  void setViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
  }

  testWidgets('fails closed until persisted declines initialize', (
    tester,
  ) async {
    final preferencesReady = Completer<SessionAdmissionPreferences>();
    final harness = _AdmissionHarness(
      preferences: _AdmissionPreferences(preloadedValue: '["guest"]'),
      preferencesOverride: (ref) => preferencesReady.future,
    );
    final videoBuilds = ValueNotifier(0);
    addTearDown(videoBuilds.dispose);

    final container = await pumpHost(
      tester,
      harness,
      videoBuilds: videoBuilds,
    );
    container.read(sessionAdmissionSettingsProvider.notifier).setEnabled(false);
    await harness.sendRequest(harness.request('before-preferences'));
    await tester.pump();

    check(harness.sent.whereType<AdmissionDecision>()).isEmpty();
    check(find.byType(SessionWaitingQueueButton).evaluate()).isEmpty();

    preferencesReady.complete(harness.preferences);
    await tester.pump();
    await tester.pump();

    await harness.sendRequest(harness.request('blocked-after-preferences'));
    await tester.pump();
    await tester.pump();

    final decisions = harness.sent.whereType<AdmissionDecision>().toList();
    check(decisions).length.equals(1);
    check(decisions.single.id).equals('blocked-after-preferences');
    check(decisions.single.approved).isFalse();

    await tester.pump(const Duration(minutes: 5));
    await tester.pumpWidget(const SizedBox.shrink());
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
      ).isLessOrEqual(tester.getRect(toolbar).top - 8);
      check(videoBuilds.value).equals(initialVideoBuilds);

      final button = tester.widget<OutlinedButton>(
        find.descendant(of: queue, matching: find.byType(OutlinedButton)),
      );
      check(button.style!.backgroundColor!.resolve({})).equals(AppTheme.cream);
      check(button.style!.foregroundColor!.resolve({})).equals(AppTheme.slate);

      await tester.tap(queue);
      await tester.pumpAndSettle();
      check(find.byType(SessionAdmissionPanel).evaluate()).length.equals(1);
      check(find.byType(KeeperAdmissionPanel).evaluate()).length.equals(1);

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
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.idle();
    },
  );

  testWidgets(
    'opens the tablet drawer from the room navigator and closes on back',
    (
      tester,
    ) async {
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
      check(tester.getSize(find.byType(SessionAdmissionPanel)).width).equals(
        sessionSidePanelWidth,
      );

      await tester
          .state<NavigatorState>(find.byKey(const Key('room-navigator')))
          .maybePop();
      await tester.pumpAndSettle();
      check(find.byType(SessionAdmissionPanel).evaluate()).isEmpty();

      await tester.pump(const Duration(minutes: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.idle();
    },
  );

  testWidgets(
    'clears a dormant dock selection before opening a tablet drawer',
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
      check(container.read(sessionAdmissionOpenProvider)).isTrue();
      check(find.byType(SessionAdmissionPanel).evaluate()).length.equals(1);

      setViewport(tester, const Size(800, 900));
      await tester.pump();
      check(find.byType(DockedSessionSidePanel).evaluate()).isEmpty();
      check(container.read(sessionAdmissionOpenProvider)).isTrue();

      await tester.tap(find.byType(SessionWaitingQueueButton));
      await tester.pumpAndSettle();
      check(container.read(sessionAdmissionOpenProvider)).isFalse();
      check(container.read(sessionChatOpenProvider)).isFalse();
      check(container.read(sessionPromptsOpenProvider)).isFalse();
      check(find.byType(SessionAdmissionPanel).evaluate()).length.equals(1);

      setViewport(tester, const Size(1200, 900));
      await tester.pump();
      check(find.byType(SessionAdmissionPanel).evaluate()).length.equals(1);

      await tester.pump(const Duration(minutes: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.idle();
    },
  );

  testWidgets(
    'docks beside the room and persists a permanent decline until it is allowed',
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
      check(tester.getSize(find.byType(DockedSessionSidePanel)).width).equals(
        sessionSidePanelWidth,
      );
      check(
        tester.getSize(find.byKey(const Key('room-navigator'))).width,
      ).equals(
        1200 - sessionSidePanelWidth,
      );

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Decline Permanently'));
      await tester.pump();
      await tester.pump();

      final declined = declinedSessionParticipantsProvider('session', 'keeper');
      check(container.read(declined).requireValue).contains('guest');
      check(harness.preferences.values.values.single).contains('guest');
      check(
        harness.sent
            .whereType<AdmissionDecision>()
            .singleWhere((decision) => decision.id == request.id)
            .approved,
      ).isFalse();

      await container.read(declined.notifier).allow('guest');
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
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.idle();
    },
  );
}
