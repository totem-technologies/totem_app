import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/core/services/analytics_service.dart';
import 'package:totem_app/core/services/deep_link_service.dart';
import 'package:totem_app/core/services/notifications_service.dart';
import 'package:totem_app/core/services/observer_service.dart';
import 'package:totem_app/firebase_options.dart';
import 'package:totem_app/navigation/app_router.dart';

Future<void> main() async {
  final bindings = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: bindings);

  unawaited(
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]),
  );

  await _setupErrorHandling();
  await dotenv.load();
  await _initializeServices();

  runApp(
    ProviderScope(observers: [ObserverService()], child: const TotemApp()),
  );
}

/// Initializes services.
///
/// Awaited services are required by the app to function correctly.
Future<void> _initializeServices() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    unawaited(AnalyticsService.instance.initialize());
    unawaited(DeepLinkService.instance.initialize());
    unawaited(NotificationsService.instance.initialize());

    debugPrint('✅ Services initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('❌ Service initialization error: $e');
    // Log error but continue app startup
    ErrorHandler.logError(e, stackTrace: stackTrace);
  }
}

Future<void> _setupErrorHandling() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    ErrorHandler.logFlutterError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorHandler.logError(error, stackTrace: stack);
    return true;
  };
}

class TotemApp extends ConsumerStatefulWidget {
  const TotemApp({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();

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
    NotificationsService.instance.requestPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      DeepLinkService.instance.handleIncomingLinks();
    }
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
