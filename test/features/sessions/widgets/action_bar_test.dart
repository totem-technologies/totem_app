import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/auth/models/auth_state.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/screens/chat_sheet.dart';
import 'package:totem_app/features/sessions/widgets/action_bar.dart';
import '../../../auth/controllers/auth_controller_mock.dart';
import '../controllers/core/session_controller_mock.dart';
import '../livekit_mocks.dart';

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

  group('ActionBarButton', () {
    testWidgets('invokes callback on tap', (tester) async {
      var taps = 0;

      await pumpWidget(
        tester,
        child: ActionBarButton(
          onPressed: () => taps++,
          child: const Icon(Icons.message),
        ),
      );

      await tester.tap(find.byType(ActionBarButton));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('is disabled when callback is null', (tester) async {
      await pumpWidget(
        tester,
        child: const ActionBarButton(
          onPressed: null,
          semanticsLabel: 'Disabled action',
          child: Icon(Icons.message),
        ),
      );

      final gesture = tester.widget<GestureDetector>(
        find.descendant(
          of: find.byType(ActionBarButton),
          matching: find.byType(GestureDetector),
        ),
      );
      expect(gesture.onTap, isNull);
    });
  });

  group('ActionBar', () {
    testWidgets('renders all provided children', (tester) async {
      await pumpWidget(
        tester,
        child: const ActionBar(
          children: [
            Text('One'),
            Text('Two'),
            Text('Three'),
          ],
        ),
      );

      expect(find.text('One'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
      expect(find.text('Three'), findsOneWidget);
    });
  });

  group('SessionActionBar', () {
    late MockSessionController session;
    late FakeRoom room;
    late MockLocalParticipant participant;
    late MockParticipantEventsListener listener;

    setUp(() {
      session = MockSessionController();
      participant = MockLocalParticipant();
      room = FakeRoom(participant);
      listener = MockParticipantEventsListener();

      when(() => session.room).thenReturn(room);

      when(
        () => participant.getTrackPublicationBySource(TrackSource.microphone),
      ).thenReturn(null);
      when(
        () => participant.getTrackPublicationBySource(TrackSource.camera),
      ).thenReturn(null);

      when(() => participant.createListener()).thenReturn(listener);

      when(() => session.isCurrentUserKeeper()).thenReturn(false);
    });

    Future<void> pumpSessionActionBar(
      WidgetTester tester, {
      required RoomScreen screen,
    }) async {
      await pumpWidget(
        tester,
        child: const SessionActionBar(),
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(AuthState.unauthenticated()),
          ),
          currentSessionProvider.overrideWith((ref) => session),
          lastSessionMessageProvider.overrideWith(
            (ref) => ref.watch(_testLastMessageProvider),
          ),
          sessionMessagesProvider.overrideWith((ref) => const []),
          isCurrentUserKeeperProvider.overrideWith((ref) => false),
          resolveCurrentScreenProvider.overrideWith((ref) => screen),
        ],
      );
    }

    Finder findPendingBadge() {
      return find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        return decoration.color == AppTheme.green &&
            decoration.shape == BoxShape.circle;
      });
    }

    testWidgets('is hidden on loading, disconnected, and error screens', (
      tester,
    ) async {
      for (final screen in [
        RoomScreen.loading,
        RoomScreen.disconnected,
        RoomScreen.error,
      ]) {
        await pumpSessionActionBar(tester, screen: screen);
        await tester.pump();

        expect(find.byType(ActionBar), findsNothing);
      }
    });

    testWidgets('shows expected controls on not-my-turn screen', (
      tester,
    ) async {
      await pumpSessionActionBar(tester, screen: RoomScreen.notMyTurn);
      await tester.pump();

      expect(find.byType(ActionBar), findsOneWidget);
      expect(find.byType(ActionBarButton), findsNWidgets(4));
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('shows expected controls on my-turn screen', (tester) async {
      await pumpSessionActionBar(tester, screen: RoomScreen.myTurn);
      await tester.pump();

      expect(find.byType(ActionBar), findsOneWidget);
      expect(find.byType(ActionBarButton), findsNWidgets(3));
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('shows pending badge and notification on new chat message', (
      tester,
    ) async {
      await pumpSessionActionBar(tester, screen: RoomScreen.notMyTurn);
      await tester.pump();

      expect(findPendingBadge(), findsNothing);

      final context = tester.element(find.byType(SessionActionBar));
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
    });

    testWidgets('opens chat sheet and clears pending badge', (tester) async {
      await pumpSessionActionBar(tester, screen: RoomScreen.notMyTurn);
      await tester.pump();

      final context = tester.element(find.byType(SessionActionBar));
      final container = ProviderScope.containerOf(context, listen: false);
      container
          .read(_testLastMessageProvider.notifier)
          .set(
            const SessionChatMessage(
              id: 'msg-2',
              sender: false,
              message: 'open chat now',
              timestamp: 2,
            ),
          );
      await tester.pump();

      expect(findPendingBadge(), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Chat'));
      await tester.pumpAndSettle();

      expect(find.byType(SessionChatSheet), findsOneWidget);
      expect(find.text('No messages yet'), findsOneWidget);
      expect(findPendingBadge(), findsNothing);

      Navigator.of(
        tester.element(find.byType(SessionActionBar)),
        rootNavigator: true,
      ).pop();
      await tester.pumpAndSettle();

      expect(find.byType(SessionChatSheet), findsNothing);
      expect(findPendingBadge(), findsNothing);
    });
  });
}
