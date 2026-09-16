@TestOn('chrome')
// ignore_for_file: depend_on_referenced_packages
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:checks/checks.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/models/profile_avatar_type_enum.dart';
import 'package:totem_core/core/api/api_client/models/user_schema.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_media_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_screen.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_web/core/navigation/web_router.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FakeUrlLauncher extends UrlLauncherPlatform {
  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async => true;
}

class _FakePreJoinMediaController extends PreJoinMediaController {
  @override
  PreJoinMediaState build(String sessionSlug) => const PreJoinMediaState(
    preferences: PreJoinMediaPreferences(isCameraOn: false, isMicOn: false),
    camera: PreJoinCaptureState(phase: PreJoinCapturePhase.disabled),
    microphone: PreJoinCaptureState(phase: PreJoinCapturePhase.disabled),
  );
}

/// A minimal [AuthController] fake used in web router tests.
class _FakeAuthController extends AuthController {
  _FakeAuthController(this.fakeState);

  final AuthState fakeState;
  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();

  @override
  AuthState build() {
    ref.onDispose(() async {
      await _controller.close();
    });
    _controller.add(fakeState);
    return fakeState;
  }

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  @override
  Future<void> checkExistingAuth() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  bool get isAuthenticated => fakeState.status == AuthStatus.authenticated;

  @override
  Future<void> logout() async {}

  @override
  UserSchema? get user => fakeState.user;
}

final _fakeUser = UserSchema(
  profileAvatarType: ProfileAvatarTypeEnum.td,
  circleCount: 0,
  email: 'test@totem.org',
  dateCreated: DateTime(2024),
);

/// Creates a test widget tree with a [ProviderScope] and [GoRouter].
Future<GoRouter> _pumpTestRouter(
  WidgetTester tester, {
  required AuthState authState,
  List<Object?> overrides = const [],
}) async {
  GoRouter? router;
  final routerOwner = WebTotemRouter();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => _FakeAuthController(authState),
        ),
        ...overrides.cast(),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          router ??= routerOwner.createRouter(ref);
          return MaterialApp.router(routerConfig: router!);
        },
      ),
    ),
  );

  await tester.pump();
  final testRouter = router!;
  addTearDown(() async {
    routerOwner.dispose();
    testRouter.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  return testRouter;
}

void main() {
  late UrlLauncherPlatform originalUrlLauncher;

  setUpAll(() {
    originalUrlLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _FakeUrlLauncher();
  });

  tearDownAll(() {
    UrlLauncherPlatform.instance = originalUrlLauncher;
  });

  setUp(() {
    AppConfig.instance = AppConfig(
      environment: Environment.development,
      apiUrl: 'https://totem.org/',
      liveKitUrl: 'https://livekit.totem.org/',
      maxPinAttempts: 5,
      vapidKey: null,
      analyticsEnabled: false,
      sentryDsn: null,
      posthogApiKey: null,
      posthogHost: 'https://us.i.posthog.com',
      privacyPolicyUrl: Uri.parse('https://totem.org/privacy/'),
      termsOfServiceUrl: Uri.parse('https://totem.org/tos/'),
      communityGuidelinesUrl: Uri.parse('https://totem.org/guidelines/'),
    );
    TotemRouter.instance = WebTotemRouter();
  });

  group('buildHomeUrl', () {
    final router = WebTotemRouter();
    test('returns correct URLs for each HomeRoute', () {
      check(
        router.buildHomeUrl(HomeRoutes.home),
      ).equals(router.baseUri.resolve('users/dashboard/').toString());
      check(
        router.buildHomeUrl(HomeRoutes.spaces),
      ).equals(router.baseUri.resolve('spaces/').toString());
      check(
        router.buildHomeUrl(HomeRoutes.blog),
      ).equals(router.baseUri.resolve('blog/').toString());
      check(
        router.buildHomeUrl(HomeRoutes.profile),
      ).equals(router.baseUri.resolve('users/profile/').toString());
    });
  });

  group('GoRouter route configuration', () {
    testWidgets('has routes for / and /:slug', (tester) async {
      final router = await _pumpTestRouter(
        tester,
        authState: AuthState.initial(),
      );

      final routes = router.configuration.routes;
      check(routes).length.equals(3);
      check((routes[0] as GoRoute).path).equals('/');
      check((routes[1] as GoRoute).path).equals('/__version');
      check((routes[2] as GoRoute).path).equals('/:slug');
    });

    testWidgets(
      '/:slug route captures the slug path parameter',
      (tester) async {
        const slug = 'test-session';
        final router = await _pumpTestRouter(
          tester,
          authState: AuthState.authenticated(user: _fakeUser),
          overrides: [
            // Stub providers to prevent API calls and media initialization.
            sessionTokenProvider(
              slug,
            ).overrideWith((ref) async => throw Exception('test')),
            sessionProvider(
              slug,
            ).overrideWith((ref) async => throw Exception('test')),
            preJoinMediaControllerProvider(
              slug,
            ).overrideWith(_FakePreJoinMediaController.new),
          ],
        );

        router.go('/$slug');
        await tester.pump();

        check(router.state.uri.path).equals('/$slug');
        check(router.state.pathParameters['slug']).equals(slug);
      },
      experimentalLeakTesting: LeakTesting.settings.withIgnored(
        classes: <String>['TextPainter'],
      ),
    );

    testWidgets('/ route matches the root path', (tester) async {
      final router = await _pumpTestRouter(
        tester,
        authState: AuthState.initial(),
      );

      router.go('/');
      await tester.pump();

      check(router.state.uri.path).equals('/');
    });
  });

  group('Auth-based redirect behavior', () {
    testWidgets(
      '/:slug shows redirect screen when unauthenticated',
      (tester) async {
        const slug = 'test-session';
        final router = await _pumpTestRouter(
          tester,
          authState: AuthState.unauthenticated(),
          overrides: [
            sessionTokenProvider(
              slug,
            ).overrideWith((ref) async => throw Exception('test')),
            sessionProvider(
              slug,
            ).overrideWith((ref) async => throw Exception('test')),
            preJoinMediaControllerProvider(
              slug,
            ).overrideWith(_FakePreJoinMediaController.new),
          ],
        );

        router.go('/$slug');
        await tester.pump();

        // _WebRedirectScreen displays a Scaffold.
        check(tester.widgetList(find.byType(Scaffold))).length.equals(1);
        // PreJoinScreen must NOT be shown.
        check(tester.widgetList(find.byType(PreJoinScreen))).length.equals(0);
      },
      experimentalLeakTesting: LeakTesting.settings.withIgnored(
        classes: <String>['TextPainter'],
      ),
    );

    test('isAuthenticated returns correct values for each auth status', () {
      check(
        _FakeAuthController(
          AuthState.authenticated(user: _fakeUser),
        ).isAuthenticated,
      ).equals(true);
      check(
        _FakeAuthController(AuthState.unauthenticated()).isAuthenticated,
      ).equals(false);
      check(
        _FakeAuthController(AuthState.initial()).isAuthenticated,
      ).equals(false);
      check(
        _FakeAuthController(AuthState.loading()).isAuthenticated,
      ).equals(false);
    });

    testWidgets('/ (root) shows redirect screen regardless of auth state', (
      tester,
    ) async {
      final router = await _pumpTestRouter(
        tester,
        authState: AuthState.initial(),
      );

      router.go('/');
      await tester.pump();

      // Root always redirects to origin via the redirect screen.
      check(tester.widgetList(find.byType(Scaffold))).length.equals(1);
    });
  });
}
