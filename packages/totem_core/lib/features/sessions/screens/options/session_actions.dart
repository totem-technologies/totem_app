import 'package:flutter/widgets.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/widgets/session_navigator_scope.dart';

/// True only when the backend confirmed ending, including an explicit retry.
Future<bool> endSessionWithErrorHandling(
  BuildContext context,
  SessionController session,
) async {
  try {
    await session.keeper.endSession();
    return true;
  } catch (error) {
    if (!context.mounted) return false;
    Future<bool>? retried;
    await ErrorHandler.handleApiError(
      sessionNavigatorContext(context),
      error,
      useRootNavigator: false,
      onRetry: () async {
        retried = () async {
          try {
            await session.keeper.endSession();
            return true;
          } catch (retryError) {
            if (context.mounted) {
              await ErrorHandler.handleApiError(
                sessionNavigatorContext(context),
                retryError,
                useRootNavigator: false,
              );
            }
            return false;
          }
        }();
        await retried;
      },
    );
    // The recovery dialog pops before its asynchronous action completes.
    final retry = retried;
    return retry != null && await retry;
  }
}
