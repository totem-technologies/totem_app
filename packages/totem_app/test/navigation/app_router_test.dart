import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
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
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_screen.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
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
  bool get isOnboardingCompleted =>
      isAuthenticated && (_currentState.user?.name.value?.isNotEmpty ?? false);

  @override
  UserSchema? get user => _currentState.user;

  void emit(AuthState nextState) {
    _currentState = nextState;
    _authChanges.add(nextState);
  }
}

class _LeavingSessionController extends SessionController {
  _LeavingSessionController(this.onLeave);

  final Future<void> Function() onLeave;

  @override
  Future<void> leave() => onLeave();
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
  Future<SessionDetailSchema>? sessionData,
  SessionController? currentSession,
}) async {
  final authController = _FakeMobileAuthController(authState);
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
        if (sessionData != null)
          sessionProvider('session-1').overrideWith((ref) => sessionData),
        if (currentSession != null)
          currentSessionProvider.overrideWith((ref) => currentSession),
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

  testWidgets(
    'rejoining the same session creates fresh pre-join state',
    (tester) async {
      final router = await _pumpRouter(
        tester,
        authState: AuthState.authenticated(
          user: _testUser(slug: 'user', name: 'Alex'),
        ),
        hasSeenWelcome: true,
        sessionData: Completer<SessionDetailSchema>().future,
      );
      router.go(RouteNames.session('session-1'));
      await tester.pump();
      await tester.pump();

      final screen = find.byType(PreJoinScreen);
      final previousState = tester.state(screen);
      final operation = (TotemRouter.instance as AppTotemRouter).rejoinSession(
        tester.element(screen),
        'session-1',
      );
      await tester.pump();
      await operation;
      await tester.pump(const Duration(milliseconds: 500));

      check(router.state.uri.path).equals(RouteNames.session('session-1'));
      check(tester.widgetList(screen).length).equals(1);
      check(identical(previousState, tester.state(screen))).equals(false);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    },
    experimentalLeakTesting: LeakTesting.settings.withIgnored(
      // auto_size_text 3.0.0 does not dispose TextPainters created while sizing.
      classes: <String>['TextPainter'],
    ),
  );

  testWidgets(
    'rejoining waits for an active session to leave before navigating',
    (tester) async {
      final leave = Completer<void>();
      var leaveCalled = false;
      final currentSession = _LeavingSessionController(() {
        leaveCalled = true;
        return leave.future;
      });
      final router = await _pumpRouter(
        tester,
        authState: AuthState.authenticated(
          user: _testUser(slug: 'user', name: 'Alex'),
        ),
        hasSeenWelcome: true,
        sessionData: Completer<SessionDetailSchema>().future,
        currentSession: currentSession,
      );
      router.go(RouteNames.session('session-1'));
      await tester.pump();
      await tester.pump();

      final screen = find.byType(PreJoinScreen);
      final operation = (TotemRouter.instance as AppTotemRouter).rejoinSession(
        tester.element(screen),
        'session-1',
      );
      await tester.pump();
      check(leaveCalled).equals(true);
      leave.complete();
      await operation;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      check(router.state.uri.path).equals(RouteNames.session('session-1'));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    },
    experimentalLeakTesting: LeakTesting.settings.withIgnored(
      classes: <String>['TextPainter'],
    ),
  );

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
