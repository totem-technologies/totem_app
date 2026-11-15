import 'package:flutter/widgets.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/widgets/session_navigator_scope.dart';

Future<void> endSessionWithErrorHandling(
  BuildContext context,
  SessionController session,
) async {
  try {
    await session.keeper.endSession();
  } catch (error) {
    if (!context.mounted) return;
    await ErrorHandler.handleApiError(
      sessionNavigatorContext(context),
      error,
      useRootNavigator: false,
      onRetry: () async {
        try {
          await session.keeper.endSession();
        } catch (e) {
          // Error already handled by handleApiError
        }
      },
    );
  }
}
