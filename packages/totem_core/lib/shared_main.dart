import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show Sentry;
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/services/analytics_service.dart';
import 'package:totem_core/core/services/notifications_service.dart';
import 'package:totem_core/core/services/observer_service.dart';

Future<void> sharedMain(
  Widget app,
  AsyncCallback init, {
  required FirebaseOptions firebaseOptions,
}) async {
  await Sentry.runZonedGuarded(
    () async {
      await dotenv.load();
      await init();

      await ErrorHandler.initialize();
      await _initializeServices(firebaseOptions);

      final container = ProviderContainer(observers: [ObserverService()]);
      await container.read(authControllerProvider.notifier).checkExistingAuth();

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: app,
        ),
      );
    },
    (exception, stackTrace) async {
      // nothing to do here
      // https://docs.sentry.io/platforms/dart/guides/flutter/usage/#platformdispatcheronerror--runzonedguarded
    },
  );
}

/// Initializes services.
///
/// Awaited services are required by the app to function correctly.
Future<void> _initializeServices(FirebaseOptions firebaseOptions) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);

  try {
    AnalyticsService.instance.initialize();
    NotificationsService.instance.initialize();
  } catch (e, stackTrace) {
    ErrorHandler.logError(
      e,
      stackTrace: stackTrace,
      message: 'Service initialization error',
    );
  }
}
