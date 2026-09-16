import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import '../../livekit_mocks.dart';

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

  testWidgets('shows pending badge and opens chat sheet', (tester) async {
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

    expect(findPendingBadge(), findsOneWidget);
    expect(find.text('New message'), findsOneWidget);
    expect(find.text('hello from chat'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Chat'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionChatPanel), findsOneWidget);
    expect(find.text('No messages yet'), findsOneWidget);

    Navigator.of(
      tester.element(find.byType(ActionBarChatButton)),
      rootNavigator: true,
    ).pop();
    await tester.pumpAndSettle();

    expect(findPendingBadge(), findsNothing);
  });

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

    expect(find.text('New message'), findsOneWidget);
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

    await tester.tap(find.bySemanticsLabel('Chat'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionChatPanel), findsOneWidget);

    final context = tester.element(find.byType(ActionBarChatButton));
    final container = ProviderScope.containerOf(context, listen: false);
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

    expect(find.text('New message'), findsNothing);
    expect(findPendingBadge(), findsNothing);
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

    // Keeper is reading Everyone with the panel open...
    await tester.tap(find.bySemanticsLabel('Chat'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionChatPanel), findsOneWidget);

    final context = tester.element(find.byType(ActionBarChatButton));
    final container = ProviderScope.containerOf(context, listen: false);

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
            participant: MockRemoteParticipant('lucas', 'Lucas'),
          ),
        );
    await tester.pump();

    expect(find.text('New message'), findsOneWidget);
  });

  testWidgets('a docked flag on a narrow viewport still opens the sheet', (
    tester,
  ) async {
    // Docked on a wide window, then resized below the dock threshold: the
    // stale flag must not make the first tap a no-op.
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    await tester.pumpAndSettle();

    // Nothing is docked at this width.
    expect(find.byType(SessionChatPanel), findsNothing);

    await tester.tap(find.bySemanticsLabel('Chat'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionChatPanel), findsOneWidget);
  });

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
                slug: 'keeper-1',
                name: 'Bruno Keeper',
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
            participant: MockRemoteParticipant('keeper-1', 'Bruno Keeper'),
          ),
        );
    await tester.pump();

    expect(find.text('New message'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Chat'));
    await tester.pumpAndSettle();

    expect(container.read(sessionChatThreadTargetProvider), 'bruno-test');
    expect(find.byType(SessionChatPanel), findsOneWidget);
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
                slug: 'lucas',
                name: 'Lucas',
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
            participant: MockRemoteParticipant('keeper-1', 'Heather'),
          ),
        );
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Chat'));
    await tester.pumpAndSettle();

    expect(container.read(sessionChatThreadTargetProvider), 'keeper-1');
  });
}
