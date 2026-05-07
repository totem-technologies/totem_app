import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/chat.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_chat_button.dart';

import '../../../../auth/controllers/auth_controller_mock.dart';

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
          home: Scaffold(body: child),
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
        isCurrentUserKeeperProvider.overrideWith(
          (ref) => false,
        ),
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

    expect(find.byType(SessionChatMessages), findsOneWidget);
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
    expect(find.byType(SessionChatMessages), findsOneWidget);

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
}
