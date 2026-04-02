import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/auth/models/auth_state.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/repositories/session_repository.dart';
import 'package:totem_app/features/sessions/screens/pre_join_screen.dart';
import 'package:totem_app/features/sessions/widgets/action_bar.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../../../mocks/flutter_foreground_task_mock.dart';
import '../../../mocks/permission_handler_mock.dart';
import '../../../setup.dart';

SessionDetailSchema _createSessionEvent({
  required DateTime start,
  required int duration,
  String slug = 'test-session',
}) {
  return SessionDetailSchema(
    slug: slug,
    title: 'Test Session',
    space: MobileSpaceDetailSchema(
      slug: 'test-space',
      title: 'Test Space',
      imageLink: null,
      shortDescription: 'A test space.',
      content: '',
      author: PublicUserSchema(
        profileAvatarType: ProfileAvatarTypeEnum.td,
        dateCreated: DateTime(2024),
      ),
      category: null,
      subscribers: 0,
      recurring: null,
      price: 0,
      nextEvents: const [],
    ),
    content: '',
    seatsLeft: 10,
    duration: duration,
    start: start,
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

JoinResponse _createJoinResponse({bool isAlreadyPresent = false}) {
  return JoinResponse(
    token: 'test-token',
    isAlreadyPresent: isAlreadyPresent,
  );
}

void main() {
  const sessionSlug = 'test-session';

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupDotenv();
    silenceLogger();
    setupMockFlutterForegroundTask();
    setupMockPermissionHandler();
  });

  tearDownAll(() {
    clearMockFlutterForegroundTask();
    clearMockPermissionHandler();
  });

  Future<void> pumpPreJoinScreen(
    WidgetTester tester, {
    JoinResponse? joinResponse,
    Exception? tokenError,
    SessionDetailSchema? event,
  }) async {
    final sessionEvent =
        event ??
        _createSessionEvent(
          start: DateTime(2024, 1, 1, 10),
          duration: 60,
          slug: sessionSlug,
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(AuthState.unauthenticated()),
          ),
          sessionTokenProvider(sessionSlug).overrideWith((ref) async {
            if (tokenError != null) {
              throw tokenError;
            }
            return joinResponse ?? _createJoinResponse();
          }),
          eventProvider(sessionSlug).overrideWith((ref) async {
            return sessionEvent;
          }),
        ],
        child: const SentryDisplayWidget(
          child: MaterialApp(
            home: PreJoinScreen(sessionSlug: sessionSlug),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
  }

  group('PreJoinScreen', () {
    testWidgets('renders the pre-join controls', (tester) async {
      await pumpPreJoinScreen(tester);

      expect(find.byType(ActionBar), findsOneWidget);
      expect(find.text('Swipe to Join'), findsOneWidget);
      expect(find.text('Welcome'), findsOneWidget);
    });

    testWidgets('shows the token error screen when the token load fails', (
      tester,
    ) async {
      await pumpPreJoinScreen(
        tester,
        tokenError: Exception('token failed'),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows the already-present dialog after a join attempt', (
      tester,
    ) async {
      await pumpPreJoinScreen(
        tester,
        joinResponse: _createJoinResponse(isAlreadyPresent: true),
      );

      await tester.drag(find.text('Swipe to Join'), const Offset(600, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.text("You're Already in This Session"),
        findsOneWidget,
      );
      expect(
        find.text(
          'You are already in this session on another device. Do you want to leave the other session and join on this device?',
        ),
        findsOneWidget,
      );
      expect(find.text('Join Here'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
