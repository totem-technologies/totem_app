import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/core/services/analytics_service.dart';
import 'package:totem_app/core/services/notifications_service.dart';
import 'package:totem_app/core/services/observer_service.dart';
import 'package:totem_app/firebase_options.dart';
import 'package:totem_app/navigation/app_router.dart';

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      unawaited(
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );

      await dotenv.load();
      await _initializeServices();

      await ErrorHandler.initialize();

      final container = ProviderContainer(observers: [ObserverService()]);
      await container.read(authControllerProvider.notifier).checkExistingAuth();

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const TotemApp(),
        ),
      );
    },
    (exception, stackTrace) async {
      ErrorHandler.logError(exception, stackTrace: stackTrace);
    },
  );
}

/// Initializes services.
///
/// Awaited services are required by the app to function correctly.
Future<void> _initializeServices() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    unawaited(AnalyticsService.instance.initialize());
    unawaited(NotificationsService.instance.initialize());
  } catch (e, stackTrace) {
    ErrorHandler.logError(
      e,
      stackTrace: stackTrace,
      message: 'Service initialization error',
    );
  }
}

class TotemApp extends ConsumerStatefulWidget {
  const TotemApp({super.key});

  @override
  ConsumerState<TotemApp> createState() => _AppState();
}

class _AppState extends ConsumerState<TotemApp> with WidgetsBindingObserver {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = createRouter(ref);
    unawaited(ref.read(notificationsProvider).requestPermissions());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      _router.refresh();
    });

    return MaterialApp.router(
      title: 'Totem',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(minScaleFactor: 0.8, maxScaleFactor: 1.5),
          ),
          child: child!,
        );
      },
    );
  }
}
