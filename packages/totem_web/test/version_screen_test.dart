import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/features/sessions/screens/pre_join_screen.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_web/core/navigation/web_router.dart';
import 'package:totem_web/core/navigation/version_screen.dart';

import '../../totem_core/test/auth/controllers/auth_controller_mock.dart';

/// Creates a test widget tree with a [ProviderScope] and [GoRouter].
Future<GoRouter> _pumpTestRouter(
  WidgetTester tester, {
  required AuthState authState,
  List<Object?> overrides = const [],
}) async {
  GoRouter? router;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => FakeAuthController(authState),
        ),
        ...overrides.cast(),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          router ??= WebTotemRouter().createRouter(ref);
          return MaterialApp.router(routerConfig: router!);
        },
      ),
    ),
  );

  await tester.pumpAndSettle();
  return router!;
}

void main() {
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

  group('/_version route', () {
    testWidgets('navigates to /_version and displays VersionScreen', (
      tester,
    ) async {
      final router = await _pumpTestRouter(
        tester,
        authState: AuthState.initial(),
      );

      router.go('/_version');
      await tester.pump();
      await tester.pump();

      expect(find.byType(VersionScreen), findsOneWidget);
    });

    testWidgets('shows version metadata tiles on VersionScreen', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: VersionScreen()));
      await tester.pump();

      // All expected labels should be visible.
      expect(find.text('Version'), findsOneWidget);
      expect(find.text('Build number'), findsOneWidget);
      expect(find.text('Environment'), findsOneWidget);
      expect(find.text('Commit SHA'), findsOneWidget);
      expect(find.text('Deployed at'), findsOneWidget);
    });

    testWidgets('shows local build message when commit is unknown', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: VersionScreen()));
      await tester.pump();

      // The "Deployed at" row should show the local build message when
      // COMMIT_SHA is not set via --web-define (as in test context).
      expect(find.text('Local development build'), findsOneWidget);
    });

    testWidgets('/_version does not conflict with /:slug routes', (
      tester,
    ) async {
      const slug = '_version';
      final router = await _pumpTestRouter(
        tester,
        authState: AuthState.unauthenticated(),
        overrides: [
          sessionTokenProvider(
            slug,
          ).overrideWith((ref) async => throw Exception('test')),
          eventProvider(
            slug,
          ).overrideWith((ref) async => throw Exception('test')),
        ],
      );

      router.go('/$slug');
      await tester.pump();

      // `/_version` should match the exact path, not the slug.
      expect(find.byType(VersionScreen), findsNothing);
      expect(find.byType(PreJoinScreen), findsNothing);
      // Falls through to the redirect screen.
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
