import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/permissions/media_control.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/chat.dart';
import 'package:totem_core/features/sessions/widgets/session_keyboard_shortcuts.dart';
import 'package:totem_core/shared/widgets/chat/message_bubble.dart';
import 'package:totem_core/shared/widgets/chat/message_input_bar.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../controllers/core/session_controller_mock.dart';
import '../controllers/features/session_device_controller_mock.dart';
import '../media/test_participants.dart';
import '../session_test_fixtures.dart';
import '../session_test_mocks.dart';

class _TestMessagesNotifier extends Notifier<List<SessionChatMessage>> {
  _TestMessagesNotifier(this._initial);

  final List<SessionChatMessage> _initial;

  @override
  List<SessionChatMessage> build() => _initial;

  // ignore: use_setters_to_change_properties
  void set(List<SessionChatMessage> value) {
    state = value;
  }
}

class _TestParticipantsNotifier extends Notifier<List<ParticipantInfo>> {
  _TestParticipantsNotifier(this.initial);

  final List<ParticipantInfo> initial;

  @override
  List<ParticipantInfo> build() => initial;

  void add(ParticipantInfo participant) => state = [...state, participant];

  void remove(ParticipantInfo participant) =>
      state = state.where((item) => item != participant).toList();
}

class _ChatSheetHarness {
  const _ChatSheetHarness({
    required this.container,
    required this.messagesProvider,
  });

  final ProviderContainer container;
  final NotifierProvider<_TestMessagesNotifier, List<SessionChatMessage>>
  messagesProvider;
}

SessionDetailSchema _createSessionEvent() {
  return SessionDetailSchema(
    slug: 'session-1',
    title: 'session',
    space: MobileSpaceDetailSchema(
      slug: 'space-1',
      title: 'Space',
      imageLink: null,
      shortDescription: 'A test space.',
      content: '',
      author: PublicUserSchema(
        profileAvatarType: ProfileAvatarTypeEnum.td,
        dateCreated: DateTime(2024),
        slug: const Omittable('keeper-1'),
        name: const Omittable('Heather'),
      ),
      category: null,
      subscribers: 0,
      recurring: null,
      price: 0,
      nextEvents: const [],
    ),
    content: '',
    seatsLeft: 10,
    duration: 60,
    start: DateTime(2024, 1, 1, 10),
    attending: true,
    open: true,
    started: true,
    cancelled: false,
    joinable: true,
    ended: false,
    rsvpUrl: '',
    joinUrl: null,
    subscribeUrl: '',
    calLink: '',
    subscribed: false,
    userTimezone: null,
    meetingProvider: MeetingProviderEnum.livekit,
  );
}

SessionRoomState _createSessionState({
  List<SessionChatMessage> messages = const [],
  List<ParticipantInfo>? participants,
}) {
  return SessionRoomState(
    connection: const ConnectionState(
      phase: SessionPhase.connected,
      state: RoomConnectionState.connected,
    ),
    participants: ParticipantsState(
      participants:
          participants ??
          [
            testParticipant('keeper-1', name: 'Heather'),
            testParticipant('lucas', name: 'Lucas'),
          ],
    ),
    turn: const SessionTurnState(
      roomState: RoomState(
        keeper: 'keeper-1',
        nextSpeaker: Omittable(''),
        currentSpeaker: Omittable(''),
        status: RoomStatus.active,
        turnState: TurnState.idle,
        sessionSlug: 'session-1',
        statusDetail: RoomStateStatusDetailActive(ActiveDetail()),
        talkingOrder: <String>[],
        version: 1,
        roundNumber: 1,
      ),
    ),
  );
}

List<Object?> _sharedOverrides({
  required bool isKeeper,
  required List<SessionChatMessage> messages,
  required SessionController session,
  required AuthState authState,
  bool overrideMessages = true,
  RoomScreen currentScreen = RoomScreen.listening,
  List<ParticipantInfo>? participants,
}) {
  return [
    authControllerProvider.overrideWith(() => FakeAuthController(authState)),
    currentSessionProvider.overrideWith((ref) => session),
    if (overrideMessages) sessionMessagesProvider.overrideWithValue(messages),
    currentSessionEventProvider.overrideWith((ref) => _createSessionEvent()),
    currentSessionStateProvider.overrideWithValue(
      _createSessionState(messages: messages, participants: participants),
    ),
    admittedSessionParticipantIdentitiesProvider.overrideWith(
      () => TestAdmittedSessionParticipantIdentities({
        'keeper-1',
        ...?participants?.map((participant) => participant.identity),
        if (participants == null) 'lucas',
      }),
    ),
    isCurrentUserKeeperProvider.overrideWith((ref) => isKeeper),
    resolveCurrentScreenProvider.overrideWith((ref) => currentScreen),
    userProfileProvider.overrideWith(
      (ref, slug) => Future.value(
        PublicUserSchema(
          slug: Omittable(slug),
          name: Omittable(slug == 'keeper-1' ? 'Heather' : 'Mocked User $slug'),
          profileAvatarType: ProfileAvatarTypeEnum.td,
          dateCreated: DateTime(2024),
        ),
      ),
    ),
  ];
}

void main() {
  Future<void> pumpChatSheet(
    WidgetTester tester, {
    required bool isKeeper,
    required List<SessionChatMessage> messages,
    required SessionController session,
    required AuthState authState,
    RoomScreen currentScreen = RoomScreen.listening,
    List<ParticipantInfo>? participants,
    NotifierProvider<_TestParticipantsNotifier, List<ParticipantInfo>>?
    participantsProvider,
    bool useScaffold = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._sharedOverrides(
            isKeeper: isKeeper,
            messages: messages,
            session: session,
            authState: authState,
            currentScreen: currentScreen,
            participants: participants,
          ).cast(),
          if (participantsProvider != null)
            sessionParticipantsProvider.overrideWith(
              (ref) => ref.watch(participantsProvider),
            ),
        ],
        child: MaterialApp(
          home: SessionKeyboardShortcuts(
            child: useScaffold
                ? const Scaffold(body: SessionChatPanel())
                : const SessionChatPanel(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<_ChatSheetHarness> pumpChatSheetWithMutableMessages(
    WidgetTester tester, {
    required bool isKeeper,
    required List<SessionChatMessage> messages,
    required SessionController session,
    required AuthState authState,
    RoomScreen currentScreen = RoomScreen.listening,
  }) async {
    final messagesProvider =
        NotifierProvider<_TestMessagesNotifier, List<SessionChatMessage>>(
          () => _TestMessagesNotifier(messages),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._sharedOverrides(
            isKeeper: isKeeper,
            messages: messages,
            overrideMessages: false,
            session: session,
            authState: authState,
            currentScreen: currentScreen,
          ).cast(),
          sessionMessagesProvider.overrideWith(
            (ref) => ref.watch(messagesProvider),
          ),
        ],
        child: const MaterialApp(
          home: SessionKeyboardShortcuts(
            child: Scaffold(body: SessionChatPanel()),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SessionChatPanel)),
      listen: false,
    );

    return _ChatSheetHarness(
      container: container,
      messagesProvider: messagesProvider,
    );
  }

  group('SessionChatSheet', () {
    final groupParticipants = [
      testParticipant('keeper-1', name: 'Heather'),
      testParticipant('lucas', name: 'Lucas'),
      testParticipant('third', name: 'Third'),
    ];
    late MockSessionController session;
    late MockSessionMessagingController messaging;
    late MockSessionDeviceController devices;

    setUp(() {
      session = MockSessionController();
      messaging = MockSessionMessagingController();
      devices = MockSessionDeviceController();
      when(() => session.messaging).thenReturn(messaging);
      when(() => session.devices).thenReturn(devices);
      when(
        () => messaging.sendMessage(
          any(),
          recipientIdentity: any(named: 'recipientIdentity'),
        ),
      ).thenAnswer((_) async => true);
      when(() => messaging.sendReaction(any())).thenAnswer((_) async {});
      when(
        () => devices.turnOn(MediaKind.microphone),
      ).thenAnswer((_) async => const TurnedOn());
      when(() => devices.disableMicrophone()).thenAnswer((_) async {});
      when(
        () => devices.turnOn(MediaKind.camera),
      ).thenAnswer((_) async => const TurnedOn());
      when(() => devices.disableCamera()).thenAnswer((_) async {});
      when(() => devices.isMicrophoneEnabled).thenReturn(false);
      when(() => devices.isCameraEnabled).thenReturn(false);
    });

    Future<void> runOnDesktop(AsyncCallback body) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    for (final isKeeper in [true, false]) {
      final role = isKeeper ? 'Keeper' : 'participant';
      final localIdentity = isKeeper ? 'keeper-1' : 'lucas';
      final recipient = isKeeper ? 'lucas' : 'keeper-1';
      final recipientName = isKeeper ? 'Lucas' : 'Heather';

      testWidgets(
        '$role defaults to private chat and cannot select empty Everyone history',
        (tester) async {
          await pumpChatSheet(
            tester,
            isKeeper: isKeeper,
            messages: const [],
            session: session,
            authState: AuthState.authenticated(
              user: UserSchema(
                email: '$localIdentity@example.com',
                slug: Omittable(localIdentity),
                name: Omittable(role),
                profileAvatarType: ProfileAvatarTypeEnum.td,
                circleCount: 0,
                dateCreated: DateTime(2024),
              ),
            ),
          );

          final container = ProviderScope.containerOf(
            tester.element(find.byType(SessionChatPanel)),
          );
          check(
            container.read(sessionChatThreadTargetProvider),
          ).equals(recipient);
          await tester.enterText(find.byType(TextField), 'Private hello');
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('message-input-send')));
          await tester.pump();
          verify(
            () => messaging.sendMessage(
              'Private hello',
              recipientIdentity: recipient,
            ),
          ).called(1);

          await tester.tap(find.text(recipientName).first);
          await tester.pumpAndSettle();
          check(
            tester.widgetList(
              find.text('Available when more participants join'),
            ),
          ).length.equals(1);
          await tester.tap(find.text('Everyone').last);
          await tester.pumpAndSettle();
          check(
            container.read(sessionChatThreadTargetProvider),
          ).equals(recipient);
        },
      );

      testWidgets('$role can select unread Everyone history with two people', (
        tester,
      ) async {
        await pumpChatSheet(
          tester,
          isKeeper: isKeeper,
          messages: const [
            SessionChatMessage(
              id: 'group-history',
              sender: false,
              message: 'Earlier message to everyone',
              timestamp: 1,
            ),
          ],
          session: session,
          authState: AuthState.authenticated(
            user: UserSchema(
              email: '$localIdentity@example.com',
              slug: Omittable(localIdentity),
              name: Omittable(role),
              profileAvatarType: ProfileAvatarTypeEnum.td,
              circleCount: 0,
              dateCreated: DateTime(2024),
            ),
          ),
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SessionChatPanel)),
        );
        check(
          container.read(sessionChatThreadTargetProvider),
        ).equals(recipient);
        container
            .read(sessionChatUnreadThreadsProvider.notifier)
            .markUnread(null);
        await tester.pump();
        check(
          container.read(sessionChatUnreadThreadsProvider).contains(null),
        ).isTrue();
        check(
          tester.widgetList(find.text('Earlier message to everyone')),
        ).isEmpty();

        await tester.tap(find.text(recipientName).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Everyone').last);
        await tester.pumpAndSettle();
        check(container.read(sessionChatThreadTargetProvider)).isNull();
        check(
          tester.widgetList(find.text('Earlier message to everyone')),
        ).length.equals(1);
        check(
          container.read(sessionChatUnreadThreadsProvider).contains(null),
        ).isFalse();
      });

      testWidgets(
        '$role defaults to Everyone when a third person joins before chat opens',
        (tester) async {
          final participantsProvider =
              NotifierProvider<
                _TestParticipantsNotifier,
                List<ParticipantInfo>
              >(
                () => _TestParticipantsNotifier(
                  groupParticipants.take(2).toList(),
                ),
              );
          final container = ProviderContainer(
            overrides: [
              ..._sharedOverrides(
                isKeeper: isKeeper,
                messages: const [],
                session: session,
                participants: groupParticipants,
                authState: AuthState.authenticated(
                  user: UserSchema(
                    email: '$localIdentity@example.com',
                    slug: Omittable(localIdentity),
                    name: Omittable(role),
                    profileAvatarType: ProfileAvatarTypeEnum.td,
                    circleCount: 0,
                    dateCreated: DateTime(2024),
                  ),
                ),
              ).cast(),
              sessionParticipantsProvider.overrideWith(
                (ref) => ref.watch(participantsProvider),
              ),
            ],
          );
          addTearDown(container.dispose);
          check(container.read(sessionParticipantsProvider).length).equals(2);
          container
              .read(participantsProvider.notifier)
              .add(groupParticipants[2]);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                home: SessionKeyboardShortcuts(
                  child: Scaffold(body: SessionChatPanel()),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          check(container.read(sessionChatThreadTargetProvider)).isNull();
          check(tester.widgetList(find.text('Everyone'))).isNotEmpty();
          if (isKeeper) {
            await tester.enterText(find.byType(TextField), 'Hello everyone');
            await tester.pump();
            await tester.tap(find.byKey(const ValueKey('message-input-send')));
            await tester.pump();
            verify(
              () => messaging.sendMessage(
                'Hello everyone',
                recipientIdentity: null,
              ),
            ).called(1);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        },
      );

      testWidgets(
        '$role switches from automatic private chat to Everyone when a third person joins',
        (tester) async {
          final participantsProvider =
              NotifierProvider<
                _TestParticipantsNotifier,
                List<ParticipantInfo>
              >(
                () => _TestParticipantsNotifier([
                  testParticipant('keeper-1', name: 'Heather'),
                  testParticipant('lucas', name: 'Lucas'),
                ]),
              );
          await pumpChatSheet(
            tester,
            isKeeper: isKeeper,
            messages: const [],
            session: session,
            participantsProvider: participantsProvider,
            authState: AuthState.authenticated(
              user: UserSchema(
                email: '$localIdentity@example.com',
                slug: Omittable(localIdentity),
                name: Omittable(role),
                profileAvatarType: ProfileAvatarTypeEnum.td,
                circleCount: 0,
                dateCreated: DateTime(2024),
              ),
            ),
          );

          final container = ProviderScope.containerOf(
            tester.element(find.byType(SessionChatPanel)),
          );
          check(
            container.read(sessionChatThreadTargetProvider),
          ).equals(recipient);
          container
              .read(participantsProvider.notifier)
              .add(testParticipant('third', name: 'Third'));
          await tester.pumpAndSettle();
          check(container.read(sessionChatThreadTargetProvider)).isNull();
          check(tester.widgetList(find.text('Everyone'))).isNotEmpty();
        },
      );

      for (final explicit in [false, true]) {
        testWidgets(
          '$role ${explicit ? 'keeps an explicitly selected' : 'clears the automatically selected'} peer when they leave',
          (tester) async {
            final participantsProvider =
                NotifierProvider<
                  _TestParticipantsNotifier,
                  List<ParticipantInfo>
                >(
                  () => _TestParticipantsNotifier(
                    groupParticipants.take(2).toList(),
                  ),
                );
            await pumpChatSheet(
              tester,
              isKeeper: isKeeper,
              messages: const [],
              session: session,
              participantsProvider: participantsProvider,
              authState: AuthState.authenticated(
                user: UserSchema(
                  email: '$localIdentity@example.com',
                  slug: Omittable(localIdentity),
                  name: Omittable(role),
                  profileAvatarType: ProfileAvatarTypeEnum.td,
                  circleCount: 0,
                  dateCreated: DateTime(2024),
                ),
              ),
            );
            final container = ProviderScope.containerOf(
              tester.element(find.byType(SessionChatPanel)),
            );
            check(
              container.read(sessionChatThreadTargetProvider),
            ).equals(recipient);
            if (explicit) {
              await tester.tap(find.text(recipientName).first);
              await tester.pumpAndSettle();
              await tester.tap(find.text(recipientName).last);
              await tester.pumpAndSettle();
            }

            container
                .read(participantsProvider.notifier)
                .remove(groupParticipants[isKeeper ? 1 : 0]);
            await tester.pumpAndSettle();
            if (explicit) {
              check(
                container.read(sessionChatThreadTargetProvider),
              ).equals(recipient);
            } else {
              check(container.read(sessionChatThreadTargetProvider)).isNull();
            }
          },
        );
      }

      testWidgets(
        '$role reopens to Everyone after a third person joins while chat is closed',
        (tester) async {
          final participantsProvider =
              NotifierProvider<
                _TestParticipantsNotifier,
                List<ParticipantInfo>
              >(
                () => _TestParticipantsNotifier(
                  groupParticipants.take(2).toList(),
                ),
              );
          final container = ProviderContainer(
            overrides: [
              ..._sharedOverrides(
                isKeeper: isKeeper,
                messages: const [],
                session: session,
                participants: groupParticipants,
                authState: AuthState.authenticated(
                  user: UserSchema(
                    email: '$localIdentity@example.com',
                    slug: Omittable(localIdentity),
                    name: Omittable(role),
                    profileAvatarType: ProfileAvatarTypeEnum.td,
                    circleCount: 0,
                    dateCreated: DateTime(2024),
                  ),
                ),
              ).cast(),
              sessionParticipantsProvider.overrideWith(
                (ref) => ref.watch(participantsProvider),
              ),
            ],
          );
          addTearDown(container.dispose);
          Widget host({required bool open}) => UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: SessionKeyboardShortcuts(
                child: Scaffold(
                  body: open
                      ? const SessionChatPanel()
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          );

          await tester.pumpWidget(host(open: true));
          await tester.pumpAndSettle();
          check(
            container.read(sessionChatThreadTargetProvider),
          ).equals(recipient);
          await tester.pumpWidget(host(open: false));
          await tester.pumpAndSettle();
          container
              .read(participantsProvider.notifier)
              .add(groupParticipants[2]);
          await tester.pump();
          await tester.pumpWidget(host(open: true));
          await tester.pumpAndSettle();
          check(container.read(sessionChatThreadTargetProvider)).isNull();
          check(tester.widgetList(find.text('Everyone'))).isNotEmpty();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        },
      );

      testWidgets(
        '$role keeps the auto-selected peer after explicitly selecting them and a third joins',
        (tester) async {
          final participantsProvider =
              NotifierProvider<
                _TestParticipantsNotifier,
                List<ParticipantInfo>
              >(
                () => _TestParticipantsNotifier(
                  groupParticipants.take(2).toList(),
                ),
              );
          await pumpChatSheet(
            tester,
            isKeeper: isKeeper,
            messages: const [],
            session: session,
            participants: groupParticipants,
            participantsProvider: participantsProvider,
            authState: AuthState.authenticated(
              user: UserSchema(
                email: '$localIdentity@example.com',
                slug: Omittable(localIdentity),
                name: Omittable(role),
                profileAvatarType: ProfileAvatarTypeEnum.td,
                circleCount: 0,
                dateCreated: DateTime(2024),
              ),
            ),
          );
          final container = ProviderScope.containerOf(
            tester.element(find.byType(SessionChatPanel)),
          );
          check(
            container.read(sessionChatThreadTargetProvider),
          ).equals(recipient);
          await tester.tap(find.text(recipientName).first);
          await tester.pumpAndSettle();
          await tester.tap(find.text(recipientName).last);
          await tester.pumpAndSettle();
          container
              .read(participantsProvider.notifier)
              .add(groupParticipants[2]);
          await tester.pumpAndSettle();
          check(
            container.read(sessionChatThreadTargetProvider),
          ).equals(recipient);
          check(tester.widgetList(find.text(recipientName))).isNotEmpty();
        },
      );

      testWidgets(
        '$role keeps an explicitly selected private thread when the group grows',
        (tester) async {
          final participantsProvider =
              NotifierProvider<
                _TestParticipantsNotifier,
                List<ParticipantInfo>
              >(() => _TestParticipantsNotifier(groupParticipants));
          await pumpChatSheet(
            tester,
            isKeeper: isKeeper,
            messages: const [],
            session: session,
            participants: groupParticipants,
            participantsProvider: participantsProvider,
            authState: AuthState.authenticated(
              user: UserSchema(
                email: '$localIdentity@example.com',
                slug: Omittable(localIdentity),
                name: Omittable(role),
                profileAvatarType: ProfileAvatarTypeEnum.td,
                circleCount: 0,
                dateCreated: DateTime(2024),
              ),
            ),
          );
          final container = ProviderScope.containerOf(
            tester.element(find.byType(SessionChatPanel)),
          );
          await tester.tap(find.text('Everyone').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text(recipientName).last);
          await tester.pumpAndSettle();
          check(
            container.read(sessionChatThreadTargetProvider),
          ).equals(recipient);

          container
              .read(participantsProvider.notifier)
              .add(testParticipant('fourth', name: 'Fourth'));
          await tester.pumpAndSettle();
          check(
            container.read(sessionChatThreadTargetProvider),
          ).equals(recipient);
          check(tester.widgetList(find.text(recipientName))).isNotEmpty();
        },
      );
    }

    testWidgets('keeps the composer above the keyboard', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await pumpChatSheet(
        tester,
        isKeeper: true,
        messages: const [],
        session: session,
        authState: AuthState.unauthenticated(),
        useScaffold: false,
      );

      check(
        tester.getBottomLeft(find.byType(MessageInputBar)).dy <= 500,
      ).isTrue();
      check(
        find
            .byKey(const ValueKey('message-input-send'))
            .hitTestable()
            .evaluate(),
      ).isNotEmpty();
      await tester.enterText(find.byType(TextField), 'Above keyboard');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('message-input-send')));
      await tester.pump();
      verify(
        () => messaging.sendMessage('Above keyboard', recipientIdentity: null),
      ).called(1);
      check(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
      ).isEmpty();
      check(tester.takeException()).isNull();
    });

    testWidgets('shows messages sent by the user and received from others', (
      tester,
    ) async {
      final mine = SessionChatMessage(
        id: 'msg-1',
        sender: true,
        message: 'My message',
        timestamp: DateTime(2024, 1, 1, 10, 25).millisecondsSinceEpoch,
        participant: testParticipant('me@example.com', isLocal: true),
      );
      final other = SessionChatMessage(
        id: 'msg-2',
        sender: false,
        message: 'Their message',
        timestamp: DateTime(2024, 1, 1, 10, 34).millisecondsSinceEpoch,
        participant: testParticipant('keeper-1', name: 'Heather'),
      );

      await pumpChatSheet(
        tester,
        isKeeper: true,
        messages: [mine, other],
        session: session,
        authState: AuthState.authenticated(
          user: UserSchema(
            email: 'me@example.com',
            name: const Omittable('Me'),
            profileAvatarType: ProfileAvatarTypeEnum.td,
            circleCount: 0,
            dateCreated: DateTime(2024),
          ),
        ),
      );

      check(tester.widgetList(find.text('My message'))).length.equals(1);
      check(tester.widgetList(find.text('Their message'))).length.equals(1);
      check(tester.widgetList(find.text('No messages yet'))).length.equals(0);
    });

    testWidgets('hides private messages while viewing Everyone', (
      tester,
    ) async {
      const group = SessionChatMessage(
        id: 'group-1',
        sender: true,
        message: 'Welcome everyone',
        timestamp: 1,
      );
      final private = SessionChatMessage(
        id: 'dm-1',
        sender: true,
        message: 'Secret for Lucas',
        timestamp: 2,
        recipientIdentity: 'lucas',
        participant: testParticipant('keeper-1', isLocal: true),
      );

      await pumpChatSheet(
        tester,
        isKeeper: true,
        messages: [group, private],
        session: session,
        participants: groupParticipants,
        authState: AuthState.authenticated(
          user: UserSchema(
            email: 'keeper@example.com',
            slug: const Omittable('keeper-1'),
            name: const Omittable('Heather'),
            profileAvatarType: ProfileAvatarTypeEnum.td,
            circleCount: 0,
            dateCreated: DateTime(2024),
          ),
        ),
      );

      check(find.text('Welcome everyone').evaluate()).length.equals(1);
      check(find.text('Secret for Lucas').evaluate()).isEmpty();
    });

    testWidgets('hides keeper thread affordances while the keeper is absent', (
      tester,
    ) async {
      await pumpChatSheet(
        tester,
        isKeeper: false,
        messages: const [],
        session: session,
        authState: AuthState.authenticated(
          user: UserSchema(
            email: 'lucas@example.com',
            slug: const Omittable('lucas'),
            name: const Omittable('Lucas'),
            profileAvatarType: ProfileAvatarTypeEnum.td,
            circleCount: 0,
            dateCreated: DateTime(2024),
          ),
        ),
        participants: [testParticipant('lucas', name: 'Lucas')],
      );

      check(
        tester.widgetList(find.text('Message Keeper privately')),
      ).length.equals(0);

      await tester.tap(find.text('Everyone').first);
      await tester.pumpAndSettle();

      check(tester.widgetList(find.text('Heather'))).length.equals(0);
    });

    testWidgets(
      'participant can privately message the Keeper on a narrow phone',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await pumpChatSheet(
          tester,
          isKeeper: false,
          messages: const [],
          session: session,
          participants: groupParticipants,
          authState: AuthState.authenticated(
            user: UserSchema(
              email: 'lucas@example.com',
              slug: const Omittable('lucas'),
              name: const Omittable('Lucas'),
              profileAvatarType: ProfileAvatarTypeEnum.td,
              circleCount: 0,
              dateCreated: DateTime(2024),
            ),
          ),
        );

        final privateAction = find.text('Message Keeper privately');
        check(privateAction.hitTestable().evaluate()).isNotEmpty();
        check(tester.takeException()).isNull();
        check(
          tester.widget<TextField>(find.byType(TextField)).enabled,
        ).equals(false);

        await tester.tap(find.text('Message Keeper privately'));
        await tester.pumpAndSettle();

        check(
          tester.widget<TextField>(find.byType(TextField)).enabled,
        ).equals(true);
        check(
          tester.widgetList(find.text('View Everyone messages')),
        ).length.equals(1);
        check(
          tester.widgetList(find.text('Message Keeper privately')),
        ).length.equals(1);

        await tester.enterText(find.byType(TextField), 'I need help');
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('message-input-send')));
        await tester.pump();

        verify(
          () => messaging.sendMessage(
            'I need help',
            recipientIdentity: 'keeper-1',
          ),
        ).called(1);

        await tester.tap(find.text('View Everyone messages'));
        await tester.pumpAndSettle();

        check(
          tester.widget<TextField>(find.byType(TextField)).enabled,
        ).equals(false);
        check(
          tester.widgetList(find.text('Message Keeper privately')),
        ).length.equals(1);
        check(find.text('Everyone').evaluate()).isNotEmpty();
      },
    );

    testWidgets('does not scroll when the reader is away from the bottom', (
      tester,
    ) async {
      final messages = List.generate(
        20,
        (index) => SessionChatMessage(
          id: 'msg-$index',
          sender: false,
          message: 'Message $index',
          timestamp: index,
          participant: testParticipant('user-$index', name: 'User $index'),
        ),
      );

      final harness = await pumpChatSheetWithMutableMessages(
        tester,
        isKeeper: false,
        messages: messages,
        session: session,
        authState: AuthState.unauthenticated(),
      );

      final scrollView = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      final controller = scrollView.controller!;

      check(tester.widgetList(find.text('Message 19'))).length.equals(1);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
      await tester.pumpAndSettle();

      check(controller.position.pixels).equals(0);
      check(tester.widgetList(find.text('Message 0'))).length.equals(1);

      final updatedMessages = [
        ...messages,
        SessionChatMessage(
          id: 'msg-20',
          sender: false,
          message: 'Newest message',
          timestamp: 20,
          participant: testParticipant('user-20', name: 'User 20'),
        ),
      ];

      harness.container
          .read(harness.messagesProvider.notifier)
          .set(updatedMessages);
      await tester.pump();
      await tester.pumpAndSettle();

      check(controller.position.pixels).equals(0);
    });

    testWidgets('follows new messages when the reader is near the bottom', (
      tester,
    ) async {
      final messages = List.generate(
        20,
        (index) => SessionChatMessage(
          id: 'near-bottom-$index',
          sender: false,
          message: 'Message $index',
          timestamp: index,
          participant: testParticipant('user-$index', name: 'User $index'),
        ),
      );

      final harness = await pumpChatSheetWithMutableMessages(
        tester,
        isKeeper: false,
        messages: messages,
        session: session,
        authState: AuthState.unauthenticated(),
      );
      final scrollView = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      final controller = scrollView.controller!;
      controller.jumpTo(controller.position.maxScrollExtent - 10);
      await tester.pump();

      harness.container.read(harness.messagesProvider.notifier).set([
        ...messages,
        SessionChatMessage(
          id: 'near-bottom-new',
          sender: false,
          message: 'Newest message',
          timestamp: 20,
          participant: testParticipant('user-20', name: 'User 20'),
        ),
      ]);
      await tester.pumpAndSettle();

      check(
        controller.position.pixels,
      ).equals(controller.position.maxScrollExtent);
    });

    testWidgets('long messages scroll clear of the hint and the thread chip', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final body = List.filled(
        30,
        'A full line of a long session message.',
      ).join('\n');
      final message = SessionChatMessage(
        id: 'long-1',
        sender: false,
        message: body,
        timestamp: DateTime(2024, 1, 1, 10, 45).millisecondsSinceEpoch,
        participant: testParticipant('keeper-1', name: 'Heather'),
        recipientIdentity: 'lucas',
      );

      await pumpChatSheet(
        tester,
        isKeeper: false,
        messages: [message],
        session: session,
        participants: groupParticipants,
        authState: AuthState.authenticated(
          user: UserSchema(
            email: 'lucas@example.com',
            slug: const Omittable('lucas'),
            name: const Omittable('Lucas'),
            profileAvatarType: ProfileAvatarTypeEnum.td,
            circleCount: 0,
            dateCreated: DateTime(2024),
          ),
        ),
      );

      await tester.tap(find.text('Message Keeper privately'));
      await tester.pumpAndSettle();

      final scrollView = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      final controller = scrollView.controller!;
      check(controller.position.maxScrollExtent).isGreaterThan(0);

      Rect scrollRect() => tester.getRect(find.byType(CustomScrollView));
      Rect bubbleRect() => tester.getRect(find.byType(MessageBubble));
      final pill = tester.getRect(
        find
            .ancestor(
              of: find.text('Private messages — only the Keeper can see them'),
              matching: find.byType(Container),
            )
            .first,
      );
      final chip = tester.getRect(
        find
            .ancestor(
              of: find.text('View Everyone messages'),
              matching: find.byType(Material),
            )
            .first,
      );

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      check(scrollRect().top - pill.bottom).isGreaterOrEqual(0);
      check(chip.top - scrollRect().bottom).isGreaterOrEqual(0);
      check(scrollRect().bottom - bubbleRect().bottom).isGreaterOrEqual(0);
      check(chip.top - bubbleRect().bottom).isGreaterOrEqual(0);

      controller.jumpTo(0);
      await tester.pump();

      check(bubbleRect().top - scrollRect().top).isGreaterOrEqual(0);
      check(bubbleRect().top - pill.bottom).isGreaterOrEqual(0);
    });

    testWidgets('sends a trimmed message from the composer', (tester) async {
      await pumpChatSheet(
        tester,
        isKeeper: true,
        messages: const [],
        session: session,
        authState: AuthState.unauthenticated(),
      );

      await tester.enterText(find.byType(TextField), '  Hello chat  ');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('message-input-send')));
      await tester.pump();

      verify(
        () => messaging.sendMessage(
          'Hello chat',
          recipientIdentity: any(named: 'recipientIdentity'),
        ),
      ).called(1);
      check(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
      ).isEmpty();
    });

    testWidgets('does not carry a private draft into the Everyone thread', (
      tester,
    ) async {
      await pumpChatSheet(
        tester,
        isKeeper: true,
        messages: const [],
        session: session,
        participants: groupParticipants,
        authState: AuthState.authenticated(
          user: UserSchema(
            email: 'keeper@example.com',
            slug: const Omittable('keeper-1'),
            name: const Omittable('Heather'),
            profileAvatarType: ProfileAvatarTypeEnum.td,
            circleCount: 0,
            dateCreated: DateTime(2024),
          ),
        ),
      );

      await tester.tap(find.text('Everyone').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lucas').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Checking in privately');
      await tester.pump();

      // Back to Everyone: the private draft must not follow.
      await tester.tap(find.text('Lucas').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Everyone').last);
      await tester.pumpAndSettle();
      check(
        tester.widgetList(find.textContaining('only you can post')),
      ).length.equals(1);

      check(
        tester.widgetList(find.text('Checking in privately')),
      ).length.equals(0);
      check(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
      ).equals('');
    });

    testWidgets('keeps the composer text when the send is rejected', (
      tester,
    ) async {
      when(
        () => messaging.sendMessage(
          any(),
          recipientIdentity: any(named: 'recipientIdentity'),
        ),
      ).thenAnswer((_) async => false);

      await pumpChatSheet(
        tester,
        isKeeper: true,
        messages: const [],
        session: session,
        authState: AuthState.unauthenticated(),
      );

      await tester.enterText(find.byType(TextField), 'Dropped message');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('message-input-send')));
      await tester.pumpAndSettle();

      // A rejected send must not silently swallow what the user typed.
      check(find.text('Dropped message').evaluate()).length.equals(1);
    });

    testWidgets('selects a recipient from the header dropdown', (tester) async {
      await pumpChatSheet(
        tester,
        isKeeper: true,
        messages: const [],
        session: session,
        participants: groupParticipants,
        authState: AuthState.authenticated(
          user: UserSchema(
            email: 'keeper@example.com',
            slug: const Omittable('keeper-1'),
            name: const Omittable('Heather'),
            profileAvatarType: ProfileAvatarTypeEnum.td,
            circleCount: 0,
            dateCreated: DateTime(2024),
          ),
        ),
      );

      await tester.tap(find.text('Everyone').first);
      await tester.pumpAndSettle();

      check(find.text('Lucas').evaluate()).isNotEmpty();
      check(
        find.textContaining('only you can post').evaluate(),
      ).length.equals(1);

      final everyoneOpen = tester.getSemantics(find.text('Everyone').last);
      check(everyoneOpen.flagsCollection.isButton).isTrue();
      check(
        everyoneOpen.flagsCollection.isSelected.toBoolOrNull(),
      ).equals(true);

      await tester.tap(find.text('Lucas').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hello Lucas');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('message-input-send')));
      await tester.pump();
      verify(
        () => messaging.sendMessage('Hello Lucas', recipientIdentity: 'lucas'),
      ).called(1);

      // Re-open on the Lucas thread and confirm selection moved.
      await tester.tap(find.text('Lucas').first);
      await tester.pumpAndSettle();

      final lucasRow = tester.getSemantics(find.text('Lucas').last);
      check(lucasRow.flagsCollection.isButton).isTrue();
      check(lucasRow.flagsCollection.isSelected.toBoolOrNull()).equals(true);

      final everyoneRow = tester.getSemantics(find.text('Everyone').last);
      check(
        everyoneRow.flagsCollection.isSelected.toBoolOrNull(),
      ).equals(false);
    });

    testWidgets('scrolls to and messages a recipient in a long list', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpChatSheet(
        tester,
        isKeeper: true,
        messages: const [],
        session: session,
        authState: AuthState.unauthenticated(),
        participants: List.generate(
          50,
          (index) =>
              testParticipant('participant-$index', name: 'Participant $index'),
        ),
      );

      await tester.tap(find.text('Everyone').first);
      await tester.pumpAndSettle();

      check(find.text('Participant 49').evaluate()).isEmpty();
      await tester.scrollUntilVisible(
        find.text('Participant 49'),
        300,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('Participant 49'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'At the end of the list');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('message-input-send')));
      await tester.pump();
      verify(
        () => messaging.sendMessage(
          'At the end of the list',
          recipientIdentity: 'participant-49',
        ),
      ).called(1);
      check(tester.takeException()).isNull();
    });

    testWidgets('Back dismisses the chat drawer and completes only its route', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var routeCompleted = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: _sharedOverrides(
            isKeeper: false,
            messages: const [],
            session: session,
            authState: AuthState.unauthenticated(),
          ).cast(),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () => unawaited(
                      showSessionChat(
                        context,
                      ).then((_) => routeCompleted = true),
                    ),
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();

      await tester.pumpAndSettle();
      check(routeCompleted).isFalse();
      await tester.enterText(find.byType(TextField), 'A draft in the drawer');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      check(routeCompleted).isTrue();
      check(find.byType(TextField).evaluate()).isEmpty();
      check(find.text('Open').hitTestable().evaluate()).length.equals(1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('typing in the composer disables session shortcuts', (
      tester,
    ) async {
      await runOnDesktop(() async {
        await pumpChatSheet(
          tester,
          isKeeper: true,
          messages: const [],
          session: session,
          authState: AuthState.unauthenticated(),
        );

        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.pump();

        verifyNever(() => devices.turnOn(MediaKind.microphone));
        verifyNever(() => messaging.sendReaction(any()));
      });
    });

    testWidgets('an open docked chat disables session shortcuts', (
      tester,
    ) async {
      await runOnDesktop(() async {
        await pumpChatSheet(
          tester,
          isKeeper: true,
          messages: const [],
          session: session,
          authState: AuthState.unauthenticated(),
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SessionChatPanel)),
          listen: false,
        );
        container
            .read(sessionPresentationProvider.notifier)
            .openPanel(SessionPanel.chat);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.pump();

        verifyNever(() => devices.turnOn(MediaKind.microphone));
      });
    });
  });
}
