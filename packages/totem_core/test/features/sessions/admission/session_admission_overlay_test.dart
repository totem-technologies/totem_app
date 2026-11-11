import 'dart:async';
import 'dart:collection';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';

import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/declined_session_participants.dart';

import 'package:totem_core/features/sessions/admission/keeper_admission_roster.dart';
import 'package:totem_core/features/sessions/admission/session_admission_overlay.dart';
import 'package:totem_core/features/sessions/admission/session_admission_scope.dart';

import 'package:totem_core/features/sessions/admission/session_admission_settings.dart';
import 'package:totem_core/features/sessions/admission/session_waiting_queue_button.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart'
    as session_state;
import 'package:totem_core/features/sessions/controllers/features/session_keeper_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/options/session_start_confirmation_dialog.dart';

import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/features/sessions/widgets/session_side_panel.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';

import '../../../setup.dart';
import '../livekit_mocks.dart';
import '../session_test_mocks.dart';

DateTime _testNow() => DateTime.utc(2026);

class _AdmissionPreferences implements SessionAdmissionPreferences {
  _AdmissionPreferences({this.readError});

  Error? readError;
  final values = <String, String>{};
  int writeCount = 0;

  @override
  String? getString(String key) {
    final error = readError;
    if (error != null) throw error;
    return values[key];
  }

  @override
  Future<bool> setString(String key, String value) async {
    writeCount++;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }
}

class _AdmissionRoom extends FakeRoom {
  _AdmissionRoom(super.participant);

  final listener = _AdmissionEvents();
  final remotes = <String, RemoteParticipant>{};

  @override
  UnmodifiableMapView<String, RemoteParticipant> get remoteParticipants =>
      UnmodifiableMapView(remotes);

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
      now: _testNow,
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
    final navigator = tester.state<NavigatorState>(
      find.byKey(const Key('room-navigator')),
    );
    showDialog<void>(
      context: navigator.context,
      useRootNavigator: false,
      builder: (_) => SessionStartConfirmationDialog(onStart: onStart),
    );
    await tester.pumpAndSettle();
  }

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
        .state<NavigatorState>(find.byKey(const Key('room-navigator')))
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

    await tester.pumpWidget(const SizedBox.shrink());
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
      return startGate.future;
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
    final navigator = tester.state<NavigatorState>(
      find.byKey(const Key('room-navigator')),
    );
    check(SessionAdmissionScope.maybeOf(navigator.context)!.requests).isEmpty();
    check(
      tester
          .widget<ConfirmationDialog>(find.byType(ConfirmationDialog))
          .confirmButtonText,
    ).equals('Admit all and start');
    startGate.complete(true);
    await tester.pumpAndSettle();
    check(find.text('Admit all and start').evaluate()).isEmpty();
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
        find.byKey(const Key('room-navigator')),
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
      await tester.pumpWidget(const SizedBox.shrink());
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
      await tester.pumpWidget(const SizedBox.shrink());
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
    await tester.pumpWidget(const SizedBox.shrink());
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
    },
  );

  testWidgets('start confirmation works without an admission scope', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
    );
    var starts = 0;
    showDialog<void>(
      context: navigatorKey.currentContext!,
      builder: (_) => SessionStartConfirmationDialog(
        onStart: () async {
          starts++;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    check(
      find.text('Are you sure you want to start the session?').evaluate(),
    ).length.equals(1);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Start session'));
    await tester.pumpAndSettle();
    check(starts).equals(1);
    check(
      find.text('Are you sure you want to start the session?').evaluate(),
    ).isEmpty();
  });

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
      await tester.pumpWidget(const SizedBox.shrink());
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

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.idle();
    });
  }

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

    await tester.pumpWidget(const SizedBox.shrink());
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
    check(harness.mediaRecipients).isEmpty();

    await tester.pumpWidget(const SizedBox.shrink());
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

      await tester.pumpWidget(const SizedBox.shrink());
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

  testWidgets('ending a Session removes its local admission data', (
    tester,
  ) async {
    final preferences = _AdmissionPreferences();
    await seedDeclined(preferences, 'guest');
    await seedRoster(preferences, members: ['guest'], revision: 2);
    final harness = _AdmissionHarness(preferences: preferences);
    final videoBuilds = ValueNotifier(0);
    addTearDown(videoBuilds.dispose);

    final container = await pumpHost(tester, harness, videoBuilds: videoBuilds);
    check(preferences.values).length.equals(2);

    when(() => harness.state.roomState).thenReturn(
      const RoomState(
        keeper: 'keeper',
        nextSpeaker: Omittable(''),
        currentSpeaker: Omittable(''),
        status: RoomStatus.ended,
        turnState: TurnState.idle,
        sessionSlug: 'session',
        statusDetail: RoomStateStatusDetailEnded(
          EndedDetail(reason: EndReason.keeperEnded),
        ),
        talkingOrder: [],
        version: 2,
        roundNumber: 1,
      ),
    );
    container.read(sessionAdmissionSettingsProvider.notifier).setEnabled(false);
    await tester.pump();
    await tester.idle();
    check(preferences.values).isEmpty();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.idle();
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
      await tester.pumpWidget(const SizedBox.shrink());
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

      await tester.pumpWidget(const SizedBox.shrink());
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

    await container
        .read(sessionKeeperControllerProvider(harness.session).notifier)
        .onParticipantRemoved!('guest');
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

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    check(
      container
          .read(sessionKeeperControllerProvider(harness.session).notifier)
          .onParticipantRemoved,
    ).isNull();
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

    await tester.pumpWidget(const SizedBox.shrink());
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
      await tester.pumpWidget(const SizedBox.shrink());
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

    await tester.pumpWidget(const SizedBox.shrink());
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
        find.text('Could not update the queue').evaluate(),
      ).length.equals(1);

      await tester.pumpWidget(const SizedBox.shrink());
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

      await tester.pumpWidget(const SizedBox.shrink());
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
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.idle();
    },
  );
}
