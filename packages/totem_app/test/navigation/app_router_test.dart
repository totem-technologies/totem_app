import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pinput/pinput.dart';
import 'package:totem_app/features/auth/controllers/auth_controller.dart';

import 'package:totem_app/features/auth/controllers/user_profile_controller.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';

import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;
import 'package:totem_core/shared/router.dart';

UserSchema _testUser({String? slug, String? name}) => UserSchema(
  slug: slug == null ? const Omittable.absent() : Omittable(slug),
  name: name == null ? const Omittable.absent() : Omittable(name),
  profileAvatarType: ProfileAvatarTypeEnum.td,
  circleCount: 0,
  isStaff: false,
  email: 'test@example.com',
  dateCreated: DateTime.utc(2024),
);

class _FakeMobileAuthController extends MobileAuthController {
  _FakeMobileAuthController(this._currentState);

  AuthState _currentState;
  final _authChanges = StreamController<AuthState>.broadcast();

  @override
  AuthState build() {
    ref.onDispose(_authChanges.close);
    return _currentState;
  }

  @override
  Stream<AuthState> get authStateChanges => _authChanges.stream;

  @override
  bool get isAuthenticated => _currentState.status == AuthStatus.authenticated;

  @override
  bool get isAuthStateResolved =>
      _currentState.status != AuthStatus.initial &&
      _currentState.status != AuthStatus.loading;

  @override
  bool get isOnboardingCompleted =>
      isAuthenticated && (_currentState.user?.name.value?.isNotEmpty ?? false);

  @override
  UserSchema? get user => _currentState.user;

  void emit(AuthState nextState) {
    _currentState = nextState;
    _authChanges.add(nextState);
  }

  @override
  Future<void> requestPin(String email) async {}

  @override
  Future<void> verifyPin(String pin) async {
    emit(
      AuthState.authenticated(
        user: _testUser(slug: 'user', name: 'Alex'),
      ),
    );
  }
}

class _FakeUserProfileController extends UserProfileController {
  _FakeUserProfileController(this._hasSeenWelcome);

  final bool _hasSeenWelcome;

  @override
  FutureOr<void> build() {}

  @override
  Future<bool> get hasSeenWelcomeOnboarding async => _hasSeenWelcome;
}

List<Override> _notificationRouteOverrides() {
  final space = MobileSpaceDetailSchema(
    slug: 'garden',
    title: 'Garden',
    imageLink: null,
    shortDescription: 'A gathering space',
    content: '',
    author: PublicUserSchema(
      profileAvatarType: ProfileAvatarTypeEnum.td,
      name: const Omittable('Keeper'),
      dateCreated: DateTime.utc(2024),
    ),
    category: null,
    subscribers: 0,
    recurring: null,
    price: 0,
    nextEvents: const [],
  );

  return [
    spaceProvider('garden').overrideWith((ref) async => space),
    for (final slug in ['gathering', 'another-session', 'prejoin'])
      sessionProvider(slug).overrideWith(
        (ref) async => SessionDetailSchema(
          slug: slug,
          title: 'Garden gathering details',
          space: space,
          content: '',
          seatsLeft: 5,
          duration: 60,
          start: DateTime.utc(2026, 8, 20, 15),
          attending: false,
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
        ),
      ),
  ];
}

Future<GoRouter> _pumpRouter(
  WidgetTester tester, {
  required AuthState authState,
  required bool hasSeenWelcome,
  void Function(_FakeMobileAuthController authController)? onAuthController,
  List<Override> extraOverrides = const [],
}) async {
  final authController = _FakeMobileAuthController(authState);
  onAuthController?.call(authController);
  final routerOwner = AppTotemRouter();
  TotemRouter.instance = routerOwner;
  GoRouter? router;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => authController),
        userProfileControllerProvider.overrideWith(
          () => _FakeUserProfileController(hasSeenWelcome),
        ),
        spacesSummaryProvider.overrideWith(
          (ref) async => throw StateError('not part of this routing test'),
        ),
        ...extraOverrides,
      ],
      child: Consumer(
        builder: (context, ref, child) {
          router ??= routerOwner.createRouter(ref);
          return MaterialApp.router(routerConfig: router!);
        },
      ),
    ),
  );
  await tester.pump();

  final testRouter = router!;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    testRouter.dispose();
    routerOwner.dispose();
    await tester.pump();
  });
  return testRouter;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
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

  group('authentication redirects', () {
    testWidgets('holds protected destinations while auth is unresolved', (
      tester,
    ) async {
      _FakeMobileAuthController? authController;
      final router = await _pumpRouter(
        tester,
        authState: AuthState.loading(),
        hasSeenWelcome: true,
        onAuthController: (controller) => authController = controller,
      );
      final destination = RouteNames.spaceSession('garden', 'gathering');

      router.go(destination);
      await tester.pump();
      check(router.state.uri.path).equals(RouteNames.welcome);
      check(router.state.uri.queryParameters['next']).equals(destination);

      authController!.emit(AuthState.unauthenticated());
      await tester.pump();
      check(router.state.uri.path).equals(RouteNames.login);
      check(router.state.uri.queryParameters['next']).equals(destination);
    });

    testWidgets('keeps PIN entry and its destination during auth loading', (
      tester,
    ) async {
      final router = await _pumpRouter(
        tester,
        authState: AuthState.loading(),
        hasSeenWelcome: true,
      );
      final destination = RouteNames.spaceSession('garden', 'gathering');
      router.go(
        Uri(
          path: RouteNames.pinEntry,
          queryParameters: {'next': destination},
        ).toString(),
      );
      await tester.pump();

      check(router.state.uri.path).equals(RouteNames.pinEntry);
      check(router.state.uri.queryParameters['next']).equals(destination);
    });

    testWidgets('first-time unauthenticated users remain on welcome', (
      tester,
    ) async {
      final router = await _pumpRouter(
        tester,
        authState: AuthState.unauthenticated(),
        hasSeenWelcome: false,
      );

      check(router.state.uri.path).equals(RouteNames.welcome);
    });

    testWidgets('returning unauthenticated users are sent to login', (
      tester,
    ) async {
      final router = await _pumpRouter(
        tester,
        authState: AuthState.unauthenticated(),
        hasSeenWelcome: true,
      );

      check(router.state.uri.path).equals(RouteNames.login);
    });

    testWidgets('completes login and PIN before redirecting to next session', (
      tester,
    ) async {
      final space = MobileSpaceDetailSchema(
        slug: 'garden',
        title: 'Garden',
        imageLink: null,
        shortDescription: 'A gathering space',
        content: '',
        author: PublicUserSchema(
          profileAvatarType: ProfileAvatarTypeEnum.td,
          name: const Omittable('Keeper'),
          dateCreated: DateTime.utc(2024),
        ),
        category: null,
        subscribers: 0,
        recurring: null,
        price: 0,
        nextEvents: const [],
      );
      final router = await _pumpRouter(
        tester,
        authState: AuthState.unauthenticated(),
        hasSeenWelcome: true,
        extraOverrides: [
          spaceProvider('garden').overrideWith((ref) async => space),
          sessionProvider('gathering').overrideWith(
            (ref) async => SessionDetailSchema(
              slug: 'gathering',
              title: 'Garden gathering details',
              space: space,
              content: '',
              seatsLeft: 5,
              duration: 60,
              start: DateTime.utc(2026, 8, 20, 15),
              attending: false,
              open: true,
              started: false,
              cancelled: false,
              joinable: false,
              ended: false,
              rsvpUrl: '/rsvp/gathering',
              joinUrl: null,
              subscribeUrl: '/subscribe/gathering',
              calLink: '/calendar/gathering',
              subscribed: true,
              userTimezone: 'UTC',
              meetingProvider: MeetingProviderEnum.livekit,
            ),
          ),
        ],
      );

      final destination = RouteNames.spaceSession('garden', 'gathering');

      router.go(destination);
      await tester.pump();
      await tester.pump();
      check(router.state.uri.path).equals(RouteNames.login);
      check(router.state.uri.queryParameters['next']).equals(destination);

      await tester.enterText(find.byType(TextFormField), 'person@example.com');
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      await tester.pump();
      check(router.state.uri.path).equals(RouteNames.pinEntry);

      await tester.enterText(find.byType(Pinput), '123456');
      await tester.pump();
      await tester.pump();

      check(router.state.uri.path).equals(destination);
      await tester.pump();
      check(
        tester.widgetList<Text>(find.text('Garden gathering details')),
      ).length.equals(2);
    });

    testWidgets('preserves a protected destination through login', (
      tester,
    ) async {
      final router = await _pumpRouter(
        tester,
        authState: AuthState.unauthenticated(),
        hasSeenWelcome: true,
      );

      router.go(RouteNames.spaceSession('garden', 'gathering'));
      await tester.pump();

      check(router.state.uri.path).equals(RouteNames.login);
      check(
        router.state.uri.queryParameters['next'],
      ).equals(RouteNames.spaceSession('garden', 'gathering'));
    });

    testWidgets('rejects external and authentication-loop destinations', (
      tester,
    ) async {
      final router = await _pumpRouter(
        tester,
        authState: AuthState.authenticated(
          user: _testUser(slug: 'user', name: 'Alex'),
        ),
        hasSeenWelcome: true,
      );

      router.go('${RouteNames.login}?next=https%3A%2F%2Fevil.example');
      await tester.pump();
      check(router.state.uri.path).equals(RouteNames.home);

      router.go('${RouteNames.login}?next=%2F%2Fevil.example');
      await tester.pump();
      check(router.state.uri.path).equals(RouteNames.home);
    });

    testWidgets('unauthenticated users cannot open protected routes', (
      tester,
    ) async {
      final router = await _pumpRouter(
        tester,
        authState: AuthState.unauthenticated(),
        hasSeenWelcome: true,
      );

      router.go(RouteNames.spaces);
      await tester.pump();

      check(router.state.uri.path).equals(RouteNames.login);
    });

    testWidgets(
      'authenticated users without a profile are sent to onboarding',
      (tester) async {
        final router = await _pumpRouter(
          tester,
          authState: AuthState.authenticated(user: _testUser(slug: 'new-user')),
          hasSeenWelcome: true,
        );

        router.go(RouteNames.home);
        await tester.pump();

        check(router.state.uri.path).equals(RouteNames.onboarding);
      },
    );

    testWidgets('completed onboarding honors its safe next destination', (
      tester,
    ) async {
      _FakeMobileAuthController? authController;
      final router = await _pumpRouter(
        tester,
        authState: AuthState.authenticated(user: _testUser(slug: 'new-user')),
        hasSeenWelcome: true,
        onAuthController: (controller) => authController = controller,
      );
      final destination = RouteNames.spaceSession('garden', 'gathering');
      router.go(
        Uri(
          path: RouteNames.onboarding,
          queryParameters: {'next': destination},
        ).toString(),
      );
      await tester.pump();

      authController!.emit(
        AuthState.authenticated(
          user: _testUser(slug: 'new-user', name: 'Alex'),
        ),
      );
      await tester.pump();

      check(router.state.uri.path).equals(destination);
    });

    testWidgets('onboarded users are kept out of authentication routes', (
      tester,
    ) async {
      final router = await _pumpRouter(
        tester,
        authState: AuthState.authenticated(
          user: _testUser(slug: 'user', name: 'Alex'),
        ),
        hasSeenWelcome: true,
      );

      router.go(RouteNames.login);
      await tester.pump();

      check(router.state.uri.path).equals(RouteNames.home);
    });
  });

  group('session notification routing', () {
    const payload = SessionNotificationPayload(
      type: NotificationType.sessionStarting,
      spaceSlug: 'garden',
      sessionSlug: 'gathering',
    );

    testWidgets('same active session notification needs no confirmation', (
      tester,
    ) async {
      final router = await _pumpRouter(
        tester,
        authState: AuthState.authenticated(
          user: _testUser(slug: 'user', name: 'Alex'),
        ),
        hasSeenWelcome: true,
        extraOverrides: _notificationRouteOverrides(),
      );
      final owner = TotemRouter.instance as AppTotemRouter;
      var confirmations = 0;
      owner.setActiveSessionNotificationHandlerForSession(
        'gathering',
        () async {
          confirmations++;
          return true;
        },
      );
      owner.handleSessionNotification(payload);

      check(confirmations).equals(0);
      check(router.state.uri.path).equals(RouteNames.home);
    });

    testWidgets('different session notification asks for confirmation', (
      tester,
    ) async {
      final router = await _pumpRouter(
        tester,
        authState: AuthState.authenticated(
          user: _testUser(slug: 'user', name: 'Alex'),
        ),
        hasSeenWelcome: true,
        extraOverrides: _notificationRouteOverrides(),
      );
      final owner = TotemRouter.instance as AppTotemRouter;
      var confirmations = 0;
      owner.setActiveSessionNotificationHandlerForSession(
        'another-session',
        () async {
          confirmations++;
          return true;
        },
      );
      router.go('/session/another-session');

      owner.handleSessionNotification(payload);
      await tester.pump();

      check(confirmations).equals(1);
      check(
        router.state.uri.path,
      ).equals(RouteNames.spaceSession('garden', 'gathering'));
    });

    testWidgets('notification during prejoin navigates without a handler', (
      tester,
    ) async {
      final router = await _pumpRouter(
        tester,
        authState: AuthState.authenticated(
          user: _testUser(slug: 'user', name: 'Alex'),
        ),
        hasSeenWelcome: true,
        extraOverrides: _notificationRouteOverrides(),
      );

      router.go('/session/prejoin');
      (TotemRouter.instance as AppTotemRouter).handleSessionNotification(
        payload,
      );
      await tester.pump();

      check(
        router.state.uri.path,
      ).equals(RouteNames.spaceSession('garden', 'gathering'));
    });

    testWidgets('notification for the same detail does not duplicate route', (
      tester,
    ) async {
      final router = await _pumpRouter(
        tester,
        authState: AuthState.authenticated(
          user: _testUser(slug: 'user', name: 'Alex'),
        ),
        hasSeenWelcome: true,
        extraOverrides: _notificationRouteOverrides(),
      );
      var confirmations = 0;
      (TotemRouter.instance as AppTotemRouter)
          .setActiveSessionNotificationHandlerForSession('gathering', () async {
            confirmations++;
            return true;
          });
      final destination = RouteNames.spaceSession('garden', 'gathering');
      router.go(destination);
      await tester.pump();

      (TotemRouter.instance as AppTotemRouter).handleSessionNotification(
        payload,
      );
      await tester.pump();

      check(confirmations).equals(0);
      check(router.state.uri.path).equals(destination);
    });
  });

  testWidgets('notification routing preserves authentication redirects', (
    tester,
  ) async {
    final router = await _pumpRouter(
      tester,
      authState: AuthState.unauthenticated(),
      hasSeenWelcome: true,
    );
    final owner = TotemRouter.instance as AppTotemRouter;

    owner.handleSessionNotification(
      const SessionNotificationPayload(
        type: NotificationType.sessionStarting,
        spaceSlug: 'garden',
        sessionSlug: 'gathering',
      ),
    );
    await tester.pump();

    check(router.state.uri.path).equals(RouteNames.login);
    check(
      router.state.uri.queryParameters['next'],
    ).equals(RouteNames.spaceSession('garden', 'gathering'));
  });

  testWidgets(
    'invalid participant deep links show a recoverable error screen',
    (tester) async {
      final router = await _pumpRouter(
        tester,
        authState: AuthState.authenticated(
          user: _testUser(slug: 'user', name: 'Alex'),
        ),
        hasSeenWelcome: true,
      );

      router.go('/messages/session/session-1/participants');
      await tester.pump();
      await tester.pump();

      check(
        router.state.uri.path,
      ).equals('/messages/session/session-1/participants');
    },
  );
}
