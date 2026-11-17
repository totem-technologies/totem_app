import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';

part 'session_chat_provider.g.dart';

/// Read-only projection; messages live only in SessionChatService.
@riverpod
List<SessionChatMessage> sessionChatMessages(
  Ref ref,
  SessionController session,
) {
  final listener = ref.invalidateSelf;
  final chat = session.chat..addListener(listener);
  ref.onDispose(() => chat.removeListener(listener));
  return chat.messages;
}
