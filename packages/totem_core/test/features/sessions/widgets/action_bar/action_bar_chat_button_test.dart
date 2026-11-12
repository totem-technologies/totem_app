import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/chat.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_chat_button.dart';

import '../../../../auth/controllers/auth_controller_mock.dart';
import '../../media/test_participants.dart';
import '../../session_test_fixtures.dart';

class _TestLastMessageNotifier extends Notifier<SessionChatMessage?> {
  @override
  SessionChatMessage? build() => null;

  // ignore: use_setters_to_change_properties
  void set(SessionChatMessage? message) {
    state = message;
  }
}

final _testLastMessageProvider =
    NotifierProvider<_TestLastMessageNotifier, SessionChatMessage?>(
      _TestLastMessageNotifier.new,
    );

Finder findPendingBadge() {
  return find.byWidgetPredicate((widget) {
    if (widget is! Container) return false;
    final decoration = widget.decoration;
    if (decoration is! BoxDecoration) return false;
    return decoration.color == AppTheme.green &&
        decoration.shape == BoxShape.circle;
  });
}

void main() {
  setUp(() {
    LeakTesting.settings = LeakTesting.settings.withIgnored(
      classes: <String>['TextPainter'],
    );
  });

  Future<void> pumpWidget(
    WidgetTester tester, {
    required Widget child,
    List<Object?> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              // Production pins the bar to the bottom; without this the
              // scaffold stretches the bar and LayoutBuilder sees full width.
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows pending badge and opens chat via the shared flag', (
    tester,
  ) async {
    await pumpWidget(
      tester,
      child: const ActionBarChatButton(),
      overrides: [
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.unauthenticated()),
        ),
        lastSessionMessageProvider.overrideWith(
          (ref) => ref.watch(_testLastMessageProvider),
        ),
        sessionMessagesProvider.overrideWith((ref) => const []),
        isCurrentUserKeeperProvider.overrideWith((ref) => false),
        currentSessionEventProvider.overrideWith((ref) => null),
      ],
    );

    final context = tester.element(find.byType(ActionBarChatButton));
    final container = ProviderScope.containerOf(context, listen: false);
    container
        .read(_testLastMessageProvider.notifier)
        .set(
          const SessionChatMessage(
            id: 'msg-1',
            sender: false,
            message: 'hello from chat',
            timestamp: 1,
          ),
        );

    await tester.pump();

    check(tester.widgetList(findPendingBadge())).length.equals(1);
    check(
      tester.widgetList(find.text('New message from Keeper')),
    ).length.equals(1);
    check(tester.widgetList(find.text('hello from chat'))).length.equals(1);

    await tester.tap(find.bySemanticsLabel('Chat'));
    await tester.pump();

    // Button only toggles the shared flag; the room screen presents chat.
    check(container.read(sessionChatOpenProvider)).isTrue();
    check(
      tester.widgetList(find.textContaining('New message')),
    ).length.equals(0);

    // Unread clears when the open panel marks the thread read.
    container.read(sessionChatUnreadThreadsProvider.notifier).markRead(null);
    await tester.pump();
    check(tester.widgetList(findPendingBadge())).length.equals(0);
  });

  testWidgets(
    'tapping an Everyone notification opens group history and clears unread',
    (tester) async {
      const message = SessionChatMessage(
        id: 'group-history',
        sender: false,
        message: 'A message for everyone',
        timestamp: 1,
      );
      await pumpWidget(
        tester,
        child: SizedBox(
          height: 500,
          child: Consumer(
            builder: (context, ref, child) => Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (ref.watch(sessionChatOpenProvider))
                  const Expanded(child: SessionChatPanel(embedded: true)),
                const ActionBarChatButton(),
              ],
            ),
          ),
        ),
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(testAuthenticatedState(slug: 'lucas')),
          ),
          lastSessionMessageProvider.overrideWith(
            (ref) => ref.watch(_testLastMessageProvider),
          ),
          sessionMessagesProvider.overrideWith((ref) => const [message]),
          sessionParticipantsProvider.overrideWith(
            (ref) => [
              testParticipant('keeper-1', name: 'Heather'),
              testParticipant('lucas', name: 'Lucas'),
            ],
          ),
          keeperIdentityProvider.overrideWith((ref) => 'keeper-1'),
          isCurrentUserKeeperProvider.overrideWith((ref) => false),
          currentSessionEventProvider.overrideWith((ref) => null),
        ],
      );

      try {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ActionBarChatButton)),
          listen: false,
        );
        await tester.pump();
        check(
          container.read(sessionChatThreadTargetProvider),
        ).equals('keeper-1');
        container.read(_testLastMessageProvider.notifier).set(message);
        await tester.pump();
        check(
          container.read(sessionChatUnreadThreadsProvider).contains(null),
        ).isTrue();
        check(tester.widgetList(findPendingBadge())).length.equals(1);

        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('A message for everyone'));
        await tester.pump();
        await tester.pump();

        check(container.read(sessionChatOpenProvider)).isTrue();
        check(container.read(sessionChatThreadTargetProvider)).isNull();
        check(
          tester.widgetList(
            find.descendant(
              of: find.byType(SessionChatPanel),
              matching: find.text('A message for everyone'),
            ),
          ),
        ).length.equals(1);
        check(
          container.read(sessionChatUnreadThreadsProvider).contains(null),
        ).isFalse();
        check(tester.widgetList(findPendingBadge())).isEmpty();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  testWidgets('does not show popup for identical message instance', (
    tester,
  ) async {
    await pumpWidget(
      tester,
      child: const ActionBarChatButton(),
      overrides: [
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.unauthenticated()),
        ),
        lastSessionMessageProvider.overrideWith(
          (ref) => ref.watch(_testLastMessageProvider),
        ),
        sessionMessagesProvider.overrideWith((ref) => const []),
        isCurrentUserKeeperProvider.overrideWith((ref) => false),
        currentSessionEventProvider.overrideWith((ref) => null),
      ],
    );

    const message = SessionChatMessage(
      id: 'msg-2',
      sender: false,
      message: 'same instance',
      timestamp: 2,
    );

    final context = tester.element(find.byType(ActionBarChatButton));
    final container = ProviderScope.containerOf(context, listen: false);
    container.read(_testLastMessageProvider.notifier).set(message);
    await tester.pump();
    container.read(_testLastMessageProvider.notifier).set(message);
    await tester.pump();

    check(
      tester.widgetList(find.textContaining('New message')),
    ).length.equals(1);
  });

  testWidgets('does not show popup while chat is open', (tester) async {
    await pumpWidget(
      tester,
      child: const ActionBarChatButton(),
      overrides: [
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.unauthenticated()),
        ),
        lastSessionMessageProvider.overrideWith(
          (ref) => ref.watch(_testLastMessageProvider),
        ),
        sessionMessagesProvider.overrideWith((ref) => const []),
        isCurrentUserKeeperProvider.overrideWith((ref) => false),
        currentSessionEventProvider.overrideWith((ref) => null),
      ],
    );

    final context = tester.element(find.byType(ActionBarChatButton));
    final container = ProviderScope.containerOf(context, listen: false);
    container.read(sessionChatOpenProvider.notifier).open = true;
    await tester.pump();

    container
        .read(_testLastMessageProvider.notifier)
        .set(
          const SessionChatMessage(
            id: 'msg-3',
            sender: false,
            message: 'while-open',
            timestamp: 3,
          ),
        );
    await tester.pump();

    check(tester.widgetList(find.text('New message'))).length.equals(0);
    check(tester.widgetList(findPendingBadge())).length.equals(0);
  });

  testWidgets('announces a message from a thread that is not on screen', (
    tester,
  ) async {
    await pumpWidget(
      tester,
      child: const ActionBarChatButton(),
      overrides: [
        authControllerProvider.overrideWith(
          () => FakeAuthController(AuthState.unauthenticated()),
        ),
        lastSessionMessageProvider.overrideWith(
          (ref) => ref.watch(_testLastMessageProvider),
        ),
        sessionMessagesProvider.overrideWith((ref) => const []),
        isCurrentUserKeeperProvider.overrideWith((ref) => true),
        currentSessionEventProvider.overrideWith((ref) => null),
      ],
    );

    final context = tester.element(find.byType(ActionBarChatButton));
    final container = ProviderScope.containerOf(context, listen: false);
    // Keeper is reading Everyone with chat marked open...
    container.read(sessionChatOpenProvider.notifier).open = true;
    await tester.pump();

    // ...when a private support request arrives on another thread.
    container
        .read(_testLastMessageProvider.notifier)
        .set(
          SessionChatMessage(
            id: 'msg-dm',
            sender: false,
            message: 'I am struggling',
            timestamp: 4,
            recipientIdentity: 'keeper-1',
            participant: testParticipant('lucas', name: 'Lucas'),
          ),
        );
    await tester.pump();

    check(
      tester.widgetList(find.text('New message from Lucas')),
    ).length.equals(1);
  });

  testWidgets(
    'keeps other-thread unread badges visible in docked chat and clears them when read',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpWidget(
        tester,
        child: const SizedBox(
          height: 500,
          child: Column(
            children: [
              Expanded(child: SessionChatPanel(embedded: true)),
              ActionBarChatButton(),
            ],
          ),
        ),
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(AuthState.unauthenticated()),
          ),
          lastSessionMessageProvider.overrideWith(
            (ref) => ref.watch(_testLastMessageProvider),
          ),
          sessionMessagesProvider.overrideWith((ref) => const []),
          isCurrentUserKeeperProvider.overrideWith((ref) => true),
          currentSessionEventProvider.overrideWith((ref) => null),
        ],
      );

      final context = tester.element(find.byType(ActionBarChatButton));
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(sessionChatOpenProvider.notifier).open = true;
      await tester.pump();

      container
          .read(_testLastMessageProvider.notifier)
          .set(
            SessionChatMessage(
              id: 'msg-docked-dm',
              sender: false,
              message: 'I need support',
              timestamp: 7,
              recipientIdentity: 'keeper-1',
              participant: testParticipant('lucas', name: 'Lucas'),
            ),
          );
      await tester.pump();

      check(tester.widgetList(findPendingBadge())).length.equals(1);
      check(
        tester.widgetList(find.textContaining('New message')),
      ).length.equals(1);

      container.read(sessionChatThreadTargetProvider.notifier).target = 'lucas';
      await tester.pump();
      await tester.pump();

      check(tester.widgetList(findPendingBadge())).length.equals(0);
    },
  );

  testWidgets('Chat opens the private thread that sent the notification', (
    tester,
  ) async {
    await pumpWidget(
      tester,
      child: const ActionBarChatButton(),
      overrides: [
        authControllerProvider.overrideWith(
          () => FakeAuthController(
            AuthState.authenticated(
              user: UserSchema(
                email: 'keeper@example.com',
                slug: const Omittable('keeper-1'),
                name: const Omittable('Bruno Keeper'),
                profileAvatarType: ProfileAvatarTypeEnum.td,
                circleCount: 0,
                dateCreated: DateTime(2024),
              ),
            ),
          ),
        ),
        lastSessionMessageProvider.overrideWith(
          (ref) => ref.watch(_testLastMessageProvider),
        ),
        sessionMessagesProvider.overrideWith((ref) => const []),
        isCurrentUserKeeperProvider.overrideWith((ref) => true),
        currentSessionEventProvider.overrideWith((ref) => null),
      ],
    );

    final context = tester.element(find.byType(ActionBarChatButton));
    final container = ProviderScope.containerOf(context, listen: false);
    container
        .read(_testLastMessageProvider.notifier)
        .set(
          SessionChatMessage(
            id: 'msg-dm',
            sender: false,
            message: 'Checking in',
            timestamp: 5,
            recipientIdentity: 'bruno-test',
            participant: testParticipant('keeper-1', name: 'Bruno Keeper'),
          ),
        );
    await tester.pump();

    check(
      tester.widgetList(find.textContaining('New message')),
    ).length.equals(1);

    await tester.tap(find.bySemanticsLabel('Chat'));
    await tester.pump();

    expect(container.read(sessionChatOpenProvider), isTrue);
    expect(container.read(sessionChatThreadTargetProvider), 'bruno-test');
  });

  testWidgets('Chat opens the sender thread for an incoming private message', (
    tester,
  ) async {
    await pumpWidget(
      tester,
      child: const ActionBarChatButton(),
      overrides: [
        authControllerProvider.overrideWith(
          () => FakeAuthController(
            AuthState.authenticated(
              user: UserSchema(
                email: 'lucas@example.com',
                slug: const Omittable('lucas'),
                name: const Omittable('Lucas'),
                profileAvatarType: ProfileAvatarTypeEnum.td,
                circleCount: 0,
                dateCreated: DateTime(2024),
              ),
            ),
          ),
        ),
        lastSessionMessageProvider.overrideWith(
          (ref) => ref.watch(_testLastMessageProvider),
        ),
        sessionMessagesProvider.overrideWith((ref) => const []),
        isCurrentUserKeeperProvider.overrideWith((ref) => false),
        currentSessionEventProvider.overrideWith((ref) => null),
      ],
    );

    final context = tester.element(find.byType(ActionBarChatButton));
    final container = ProviderScope.containerOf(context, listen: false);
    container
        .read(_testLastMessageProvider.notifier)
        .set(
          SessionChatMessage(
            id: 'msg-from-keeper',
            sender: false,
            message: 'How are you holding up?',
            timestamp: 6,
            recipientIdentity: 'lucas',
            participant: testParticipant('keeper-1', name: 'Heather'),
          ),
        );
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Chat'));
    await tester.pump();

    expect(container.read(sessionChatOpenProvider), isTrue);
    expect(container.read(sessionChatThreadTargetProvider), 'keeper-1');
  });
}
