import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;
import 'package:totem_app/features/auth/controllers/auth_controller.dart';
import 'package:totem_app/features/auth/controllers/user_profile_controller.dart';

import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/shared/router.dart';

class TestMobileAuthController extends MobileAuthController {
  TestMobileAuthController({AuthState? initialState})
    : _initialState = initialState ?? AuthState.unauthenticated();

  final AuthState _initialState;
  final _authChanges = StreamController<AuthState>.broadcast();
  Future<void> Function(String email)? onRequestPin;
  Future<void> Function(String pin)? onVerifyPin;
  int requestPinCalls = 0;
  int verifyPinCalls = 0;

  @override
  AuthState build() {
    ref.onDispose(_authChanges.close);
    return _initialState;
  }

  @override
  Stream<AuthState> get authStateChanges => _authChanges.stream;

  @override
  bool get isAuthenticated => _initialState.status == AuthStatus.authenticated;

  @override
  bool get isOnboardingCompleted =>
      isAuthenticated && (_initialState.user?.name?.isNotEmpty ?? false);

  @override
  UserSchema? get user => _initialState.user;

  @override
  Future<void> requestPin(String email) async {
    requestPinCalls++;
    await onRequestPin?.call(email);
  }

  @override
  Future<void> verifyPin(String pin) async {
    verifyPinCalls++;
    await onVerifyPin?.call(pin);
  }

  @override
  Future<void> checkExistingAuth() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> logout() async {}
}

class TestUserProfileController extends UserProfileController {
  int markWelcomeCalls = 0;
  int completeOnboardingCalls = 0;
  Future<void> Function()? onMarkWelcome;
  Future<void> Function()? onCompleteOnboarding;

  @override
  FutureOr<void> build() {}

  @override
  Future<void> markWelcomeOnboardingCompleted() async {
    markWelcomeCalls++;
    await onMarkWelcome?.call();
  }

  @override
  Future<void> completeOnboarding({
    required String firstName,
    required int? age,
    required ReferralChoices? referralSource,
    required Set<SpaceCategories> interestTopics,
    required bool newsletterConsent,
    String? referralOther,
  }) async {
    completeOnboardingCalls++;
    await onCompleteOnboarding?.call();
  }
}

void configureAuthScreenTests() {
  AppConfig? previousConfig;
  try {
    previousConfig = AppConfig.instance;
  } on StateError {
    // The first test in this library has no application config to restore.
  }

  final testConfig = AppConfig(
    environment: Environment.development,
    apiUrl: 'https://test.example.com/',
    liveKitUrl: 'wss://test.livekit.cloud',
    maxPinAttempts: 3,
    vapidKey: null,
    analyticsEnabled: false,
    sentryDsn: null,
    posthogApiKey: null,
    posthogHost: 'https://us.i.posthog.com',
    privacyPolicyUrl: Uri.parse('https://example.com/privacy'),
    termsOfServiceUrl: Uri.parse('https://example.com/tos'),
    communityGuidelinesUrl: Uri.parse('https://example.com/guidelines'),
  );
  AppConfig.instance = testConfig;
  addTearDown(() {
    AppConfig.instance = previousConfig ?? testConfig;
  });
}

Future<GoRouter> pumpAuthScreen(
  WidgetTester tester, {
  required Widget screen,
  required String initialPath,
  required List<Override> overrides,
  List<GoRoute> additionalRoutes = const [],
}) async {
  final destinationRoutes = <GoRoute>[
    GoRoute(
      path: RouteNames.login,
      builder: (_, _) => const Text('login destination'),
    ),
    GoRoute(
      path: RouteNames.pinEntry,
      builder: (_, _) => const Text('pin destination'),
    ),
    GoRoute(
      path: RouteNames.onboarding,
      builder: (_, _) => const Text('onboarding destination'),
    ),
    GoRoute(
      path: RouteNames.home,
      builder: (_, _) => const Text('home destination'),
    ),
    GoRoute(
      path: RouteNames.welcome,
      builder: (_, _) => const Text('welcome destination'),
    ),
    ...additionalRoutes,
  ];
  final routes = <GoRoute>[
    GoRoute(path: initialPath, builder: (_, _) => screen),
    ...destinationRoutes.where((route) => route.path != initialPath),
  ];

  final router = GoRouter(initialLocation: initialPath, routes: routes);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: mui.MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => mui.ScaffoldMessenger(
          child: mui.Scaffold(body: child ?? const SizedBox.shrink()),
        ),
      ),
    ),
  );
  await tester.pump();
  return router;
}

Future<void> disposeAuthScreenTest(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  router.dispose();
}
