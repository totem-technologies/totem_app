import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/services/observer_service.dart';

import 'app/totem_app.dart';
import 'core/errors/error_handler.dart';
import 'core/services/analytics_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await dotenv.load(fileName: '.env');
  await _initializeServices();
  await _setupErrorHandling();

  runApp(
    ProviderScope(observers: [ObserverService()], child: const TotemApp()),
  );
}

Future<void> _initializeServices() async {
  try {
    await AnalyticsService.instance.initialize();

    // Initialize other services here
    // - Deep linking
    // - Notifications
    // - Secure storage setup
    // - API client configuration

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
