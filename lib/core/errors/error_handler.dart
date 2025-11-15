import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' show LiveKitException;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/logger.dart';

/// Centralized error handling for the Totem App.
///
/// This class provides methods for handling, logging, and displaying errors
/// throughout the application in a consistent manner.
class ErrorHandler {
  const ErrorHandler._();

  static Future<void> initialize() async {
    if (AppConfig.sentryDsn.isNotEmpty) {
      await SentryFlutter.init((options) {
        options
          ..dsn = AppConfig.sentryDsn
          ..navigatorKey = navigatorKey
          // Adds request headers and IP for users, for more info visit:
          // https://docs.sentry.io/platforms/dart/guides/flutter/data-management/data-collected/
          ..sendDefaultPii = true;
        //
      });
    }
  }

  static void logError(
    dynamic error, {
    StackTrace? stackTrace,
    String? reason,
    String? message,
  }) {
    if (kDebugMode) {
      logger.e(message ?? reason, error: error, stackTrace: stackTrace);
    } else if (AppConfig.sentryDsn.isNotEmpty) {
      unawaited(
        Sentry.captureException(error, stackTrace: stackTrace, hint: Hint()),
      );
    }
  }

  static void logFlutterError(FlutterErrorDetails details) {
    logError(
      details.exception,
      stackTrace: details.stack,
      reason: details.exceptionAsString(),
    );
  }

  /// Handle an exception and return a user-friendly error message
  static String getUserFriendlyErrorMessage(Object error) {
    if (is404(error)) {
      return "This page doesn't exist";
    } else if (error is AppNetworkException ||
        error is DioException ||
        error is TimeoutException) {
      return 'Oops! Something went wrong.\nPlease try again later.';
    } else if (error is AppAuthException) {
      return 'Authentication error. Please log in again.';
    } else if (error is AppDataException ||
        error is FormatException ||
        error is PlatformException) {
      return 'There was an issue processing your data. Please try again.';
    } else {
      return 'Oops! Something went wrong.';
    }
  }

  static bool is404(Object? error) {
    if (error is AppNetworkException) {
      return error.code == 'HTTP_ERROR_404';
    } else if (error is DioException) {
      return error.response?.statusCode == 404;
    } else {
      return false;
    }
  }

  /// Show a snackbar with an error message
  static void showErrorSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).clearSnackBars();
    late ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller;
    controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          spacing: 12,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
          ],
        ),
        duration: duration,
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () {
            controller.close();
          },
        ),
      ),
    );
  }

  /// Show an error dialog with a title and message
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String message,
    String title = 'Error',
    String buttonText = 'OK',
  }) async {
    final theme = Theme.of(context);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: theme.textTheme.titleLarge),
          content: SingleChildScrollView(
            child: Text(message, style: theme.textTheme.bodyMedium),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(buttonText),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Handle an API error and take appropriate action
  static Future<void> handleApiError(
    BuildContext context,
    Object error, {
    StackTrace? stackTrace,
    VoidCallback? onRetry,
    bool showError = true,
  }) async {
    logError(error, stackTrace: stackTrace);

    if (!context.mounted || !showError) return;

    // Get user-friendly message
    final message = getUserFriendlyErrorMessage(error);

    // If it's an auth error, we might need to re-authenticate
    if (error is AppAuthException) {
      await showErrorDialog(
        context,
        title: 'Authentication Error',
        message: message,
        buttonText: 'Log In Again',
      );
    } else
    // For network errors, we might want to offer a retry
    if (error is AppNetworkException && onRetry != null) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Connection Error'),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Retry'),
                onPressed: () {
                  Navigator.of(context).pop();
                  onRetry();
                },
              ),
            ],
          );
        },
      );
    } else
    // For other errors, just show a snackbar
    {
      showErrorSnackBar(context, message);
    }
  }

  static void handleLivekitError(LiveKitException error) {
    logError(error, message: error.message);
  }
}
