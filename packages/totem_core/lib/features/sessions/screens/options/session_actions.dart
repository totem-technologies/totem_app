import 'package:flutter/widgets.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';

Future<void> endSessionWithErrorHandling(
  BuildContext context,
  SessionController session,
) async {
  try {
    await session.keeper.endSession();
  } catch (error) {
    if (!context.mounted) return;
    await ErrorHandler.handleApiError(
      context,
      error,
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
