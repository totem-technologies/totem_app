import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_app/features/auth/controllers/auth_controller.dart';

import 'package:totem_app/features/auth/controllers/user_profile_controller.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';

import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
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
}

class _FakeUserProfileController extends UserProfileController {
  _FakeUserProfileController(this._hasSeenWelcome);

  final bool _hasSeenWelcome;

  @override
  FutureOr<void> build() {}

  @override
  Future<bool> get hasSeenWelcomeOnboarding async => _hasSeenWelcome;
}

Future<GoRouter> _pumpRouter(
  WidgetTester tester, {
  required AuthState authState,
  required bool hasSeenWelcome,
  void Function(_FakeMobileAuthController authController)? onAuthController,
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
    await tester.pump();
    routerOwner.dispose();
    testRouter.dispose();
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
