import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/presentation/session_action_feedback.dart';

/// True only when the backend confirmed ending.
///
/// A failure is reported as a room banner; the caller keeps its dialog open so
/// confirming again is the retry.
Future<bool> endSessionWithErrorHandling(
  BuildContext context,
  SessionController session,
) async {
  final feedback = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(sessionActionFeedbackProvider.notifier);
  try {
    await session.keeper.endSession();
    return true;
  } catch (error, stackTrace) {
    feedback.report(SessionAction.endSession, error, stackTrace: stackTrace);
    return false;
  }
}
