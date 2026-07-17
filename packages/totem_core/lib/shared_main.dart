// ignore_for_file: experimental_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/services/analytics_service.dart';
import 'package:totem_core/core/services/observer_service.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/widgets/error_screen.dart';

Future<void> sharedMain(
  Widget app,
  AsyncCallback init, {
  List<Override> providerOverrides = const [],
}) async {
  // Install Sentry's binding before anything else triggers binding init
  // (e.g. AppConfig.build via rootBundle). SentryWidgetsFlutterBinding is
  // a no-op if a different WidgetsBinding has already been created, so
  // its frame-timing instrumentation requires being first.
  SentryWidgetsFlutterBinding.ensureInitialized();
  AppConfig.instance = await AppConfig.build();

  try {
    Future<void> launch(Widget rootChild) async {
      await init();
      _initializeBestEffortServices();
      final container = ProviderContainer(
        observers: [ObserverService()],
        overrides: providerOverrides,
        retry: _retryPolicy,
      );
      await container.read(authControllerProvider.notifier).checkExistingAuth();
      runApp(UncontrolledProviderScope(container: container, child: rootChild));
    }

    final dsn = AppConfig.instance.sentryDsn;
    if (dsn != null && dsn.isNotEmpty) {
      await SentryFlutter.init(
        _configureSentry,
        appRunner: () => launch(SentryWidget(child: app)),
      );
    } else {
      await launch(app);
    }
  } catch (error, stackTrace) {
    ErrorHandler.logError(
      error,
      stackTrace: stackTrace,
      message: 'App startup failed',
    );
    runApp(
      MaterialApp(
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const ErrorScreen(hideAppBar: true),
      ),
    );
  }
}

/// Riverpod retries failed providers by default (exponential backoff, up to
/// 10 attempts). A 4xx is a definitive answer — e.g. joining a session that
/// isn't joinable — so repeating the request only hammers the API and keeps
/// the UI cycling. 5xx and network-level failures keep the default retry.
Duration? _retryPolicy(int retryCount, Object error) {
  if (error is ApiError && error.statusCode < 500) return null;
  return ProviderContainer.defaultRetry(retryCount, error);
}

void _configureSentry(SentryFlutterOptions options) {
  final config = AppConfig.instance;
  options
    ..environment = config.environment.name
    ..dsn = config.sentryDsn
    ..navigatorKey = TotemRouter.instance.navigatorKey
    ..sendDefaultPii = true
    ..tracesSampleRate = config.isDevelopment ? 1.0 : 0.1
    ..profilesSampleRate = config.isDevelopment ? 1.0 : 0.1
    ..enableLogs = true
    ..attachScreenshot = true
    ..attachViewHierarchy = true
    ..enableAutoPerformanceTracing = true
    ..enableTimeToFullDisplayTracing = true
    ..enableTombstone = true;
}

void _initializeBestEffortServices() {
  try {
    AnalyticsService.instance.initialize();
  } catch (e, stackTrace) {
    ErrorHandler.logError(
      e,
      stackTrace: stackTrace,
      message: 'Service initialization error',
    );
  }
}
