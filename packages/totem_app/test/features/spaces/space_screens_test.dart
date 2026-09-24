import 'package:checks/checks.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_app/features/spaces/screens/session_deep_link_screen.dart';
import 'package:totem_app/features/spaces/screens/session_history.dart';
import 'package:totem_app/features/spaces/screens/spaces_discovery_screen.dart';
import 'package:totem_app/features/spaces/screens/subcribed_spaces.dart';
import 'package:totem_app/features/spaces/widgets/attending_dialog.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/repositories/space_repository.dart';

final class _FakeAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);

  @override
  Future<void> checkExistingAuth() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  bool get isAuthenticated => false;

  @override
  Future<void> logout() async {}

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  UserSchema? get user => null;
}

MobileSpaceDetailSchema _space(String slug, String title, {String? category}) =>
    MobileSpaceDetailSchema(
      slug: slug,
      title: title,
      imageLink: null,
      shortDescription: 'Description',
      content: '',
      author: PublicUserSchema(
        profileAvatarType: ProfileAvatarTypeEnum.td,
        name: const Omittable('Keeper'),
        dateCreated: DateTime.utc(2026),
      ),
      category: category,
      subscribers: 3,
      recurring: null,
      price: 0,
      nextEvents: const [],
    );

SessionDetailSchema _session(String slug, MobileSpaceDetailSchema space) =>
    SessionDetailSchema(
      slug: slug,
      title: 'Session $slug',
      space: space,
      content: '',
      seatsLeft: 0,
      duration: 60,
      start: DateTime.utc(2026, 8, 20, 15),
      attending: slug == 'attending',
      open: true,
      started: false,
      cancelled: false,
      joinable: false,
      ended: false,
      rsvpUrl: '/rsvp/$slug',
      joinUrl: null,
      subscribeUrl: '/subscribe/$slug',
      calLink: '/calendar/$slug',
      subscribed: true,
      userTimezone: 'UTC',
      meetingProvider: MeetingProviderEnum.livekit,
    );

void main() {
  setUpAll(() {
    AppConfig.instance = AppConfig(
      environment: Environment.development,
      apiUrl: 'https://test.example.com/',
      liveKitUrl: 'wss://test.livekit.cloud',
      maxPinAttempts: 5,
      vapidKey: null,
      analyticsEnabled: false,
      sentryDsn: null,
      posthogApiKey: null,
      posthogHost: 'https://us.i.posthog.com',
      privacyPolicyUrl: Uri.parse('https://example.com/privacy'),
      termsOfServiceUrl: Uri.parse('https://example.com/tos'),
      communityGuidelinesUrl: Uri.parse('https://example.com/guidelines'),
    );
  });

  testWidgets(
    'discovery shows its empty state when no sessions are available',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spacesSummaryProvider.overrideWith(
              (_) async => const SummarySpacesSchema(
                upcoming: [],
                forYou: [],
                explore: [],
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SpacesDiscoveryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      check(
        tester.widgetList(find.text('No sessions available yet.')),
      ).length.equals(1);
    },
  );

  testWidgets('history and subscribed screens expose empty-state actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuthController.new),
          listSessionsHistoryProvider.overrideWith((_) async => []),
          listSubscribedSpacesProvider.overrideWith((_) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SessionHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    check(
      tester.widgetList(find.text('You have not joined any sessions yet.')),
    ).length.equals(1);
    check(tester.widgetList(find.text('Browse Spaces'))).length.equals(1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuthController.new),
          listSubscribedSpacesProvider.overrideWith((_) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SubscribedSpacesScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    check(
      tester.widgetList(find.text('You are not subscribed to any Spaces.')),
    ).length.equals(1);
  });

  testWidgets('session deep link resolves to the session route after loading', (
    tester,
  ) async {
    final space = _space('community', 'Community');
    final session = _session('welcome', space);
    final router = GoRouter(
      initialLocation: '/deep',
      routes: [
        GoRoute(
          path: '/deep',
          builder: (_, _) =>
              const SessionDeepLinkScreen(sessionSlug: 'welcome'),
        ),
        GoRoute(
          path: '/spaces/:space/session/:session',
          builder: (_, state) =>
              Text('Opened ${state.pathParameters['session']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider('welcome').overrideWith((_) async => session),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    check(tester.widgetList(find.text('Opened welcome'))).length.equals(1);
  });

  testWidgets(
    'attending dialog changes calendar action after permission callback succeeds',
    (tester) async {
      var calendarCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AttendingDialog(
              sessionSlug: 'welcome',
              onAddToCalendar: () async => calendarCalls++,
            ),
          ),
        ),
      );

      check(tester.widgetList(find.text('Add to Calendar'))).length.equals(1);
      await tester.tap(find.text('Add to Calendar'));
      await tester.pump();
      check(calendarCalls).equals(1);
      check(tester.widgetList(find.text('Added!'))).length.equals(1);
    },
  );
}
