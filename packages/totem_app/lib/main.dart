import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/services/notifications_service.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/services/analytics_service.dart';
import 'package:totem_core/core/services/observer_service.dart';
import 'package:totem_core/firebase_options.dart';
import 'package:totem_core/shared/assets.dart';

Future<void> main() async {
  await Sentry.runZonedGuarded(
    () async {
      await dotenv.load();
      await ErrorHandler.initialize();
      await _initializeServices();

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
      // nothing to do here
      // https://docs.sentry.io/platforms/dart/guides/flutter/usage/#platformdispatcheronerror--runzonedguarded
    },
  );
}

/// Initializes services.
///
/// Awaited services are required by the app to function correctly.
Future<void> _initializeServices() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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

class TotemApp extends ConsumerStatefulWidget {
  const TotemApp({super.key});

  @override
  ConsumerState<TotemApp> createState() => _AppState();
}

class _AppState extends ConsumerState<TotemApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  bool _imagesPrecached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = createRouter(ref);
    ref.read(notificationsProvider).requestPermissions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      final authState = ref.read(authControllerProvider.notifier);
      if (!authState.isOnboardingCompleted) {
        for (final path in <String>[
          TotemImageAssets.onboarding1,
          TotemImageAssets.onboarding2,
          TotemImageAssets.onboarding3,
        ]) {
          precacheImage(AssetImage(path), context);
        }
      }
    }
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
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.8,
          maxScaleFactor: 1.5,
          child: child!,
        );
      },
    );
  }
}
