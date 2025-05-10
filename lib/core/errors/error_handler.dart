import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/main.dart';

/// Centralized error handling for the Totem App.
///
/// This class provides methods for handling, logging, and displaying errors
/// throughout the application in a consistent manner.
class ErrorHandler {
  const ErrorHandler._();

  static const String _tag = 'ErrorHandler';

  static Future<void> initialize(VoidCallback runApp) async {
    await SentryFlutter.init((options) {
      options
        ..dsn = AppConfig.sentryDsn
        ..navigatorKey = TotemApp.navigatorKey
        // Adds request headers and IP for users, for more info visit:
        // https://docs.sentry.io/platforms/dart/guides/flutter/data-management/data-collected/
        ..sendDefaultPii = true;
      //
      // ignore: require_trailing_commas
    }, appRunner: runApp);
  }

  static void logError(Object error, {StackTrace? stackTrace, String? reason}) {
    if (kDebugMode) {
      debugPrint('[$_tag] 🔴 Error: $error');
      if (stackTrace != null) {
        debugPrint('[$_tag] Stack trace: $stackTrace');
      }
    }
    if (reason != null) debugPrint('📊 $reason');
    Sentry.captureException(error, stackTrace: stackTrace, hint: Hint());
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
    if (error is AppNetworkException) {
      return 'Unable to connect to the server. Please check your internet '
          'connection and try again.';
    } else if (error is AppAuthException) {
      return 'Authentication error. Please log in again.';
    } else if (error is AppDataException) {
      return 'There was an issue processing your data. Please try again.';
    } else if (error is PlatformException) {
      return 'There was an issue with your device. Please try again.';
    } else if (error is TimeoutException) {
      return 'The operation timed out. Please try again.';
    } else if (error is FormatException) {
      return 'There was an issue with the data format. Please try again.';
    } else {
      // Generic error message for unknown errors
      return 'Something went wrong. Please try again later.';
    }
  }

  /// Show a snackbar with an error message
  static void showErrorSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
          ],
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: theme.colorScheme.surface,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: theme.colorScheme.primary,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
  }) async {
    // Log the error first
    logError(error, stackTrace: stackTrace);

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
      return;
    }

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
      return;
    }

    // For other errors, just show a snackbar
    showErrorSnackBar(context, message);
  }
}
