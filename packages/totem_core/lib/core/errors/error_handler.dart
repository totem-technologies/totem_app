import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' show LiveKitException;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/shared/logger.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';

/// Centralized error handling for the Totem App.
class ErrorHandler {
  const ErrorHandler._();

  static void logError(
    dynamic error, {
    StackTrace? stackTrace,
    String? message,
  }) {
    if (kDebugMode) {
      logger.e(message, error: error, stackTrace: stackTrace);
    }

    if (AppConfig.instance.sentryDsn != null &&
        AppConfig.instance.sentryDsn!.isNotEmpty) {
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        message: message != null ? SentryMessage(message) : null,
      );
    }
  }

  static void logFlutterError(FlutterErrorDetails details) {
    logError(
      details.exception,
      stackTrace: details.stack,
      message: 'Flutter Error in ${details.library ?? "unknown"}',
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
      return 'Authentication error. Please sign in again.';
    } else if (error is AppDataException ||
        error is FormatException ||
        error is PlatformException) {
      return 'Something unexpected happened. Please try again.';
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
  static void showErrorSnackBar(BuildContext context, String message) {
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
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
      ),
    );
  }

  /// Show an error dialog with a title and message
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String message,
    String title = 'Something Went Wrong',
    String buttonText = 'OK',
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return ConfirmationDialog(
          title: title,
          content: message,
          confirmButtonText: buttonText,
          icon: TotemIcons.errorOutlined,
          onConfirm: () async {
            Navigator.of(context).pop();
          },
          showCancel: false,
        );
      },
    );
  }

  /// Handle an API error and take appropriate action
  static Future<void> handleApiError(
    BuildContext context,
    Object error, {
    StackTrace? stackTrace,
    AsyncCallback? onRetry,
    bool showError = true,
  }) async {
    logError(error, stackTrace: stackTrace);
    if (!context.mounted || !showError) return;

    final message = getUserFriendlyErrorMessage(error);

    // If it's an auth error, we might need to re-authenticate
    if (error is AppAuthException) {
      await showErrorDialog(
        context,
        title: 'Authentication Error',
        message: message,
        buttonText: 'Sign In Again',
      );
    } else
    // For network errors, allow retry
    if (error is AppNetworkException && onRetry != null) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return ConfirmationDialog(
            title: 'Something Went Wrong',
            content: message,
            confirmButtonText: 'Retry',
            onConfirm: () async {
              Navigator.of(context).pop();
              await onRetry();
            },
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
