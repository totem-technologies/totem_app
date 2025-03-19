import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/totem_app.dart';
import 'core/services/analytics_service.dart';
import 'core/errors/error_handler.dart';

/// Application entry point
Future<void> main() async {
  // Ensure Flutter bindings are initialized before calling native code
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize app services
  await _initializeServices();

  // Set up global error handling
  await _setupErrorHandling();

  // Run the app with Riverpod
  runApp(const ProviderScope(child: TotemApp()));
}

/// Initialize services required before app starts
Future<void> _initializeServices() async {
  try {
    // Initialize analytics
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

/// Set up global error handling for the app
Future<void> _setupErrorHandling() async {
  // Capture Flutter errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    ErrorHandler.logFlutterError(details);
  };

  // Capture async errors that aren't caught by FlutterError.onError
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorHandler.logError(error, stackTrace: stack);
    return true;
  };
}
