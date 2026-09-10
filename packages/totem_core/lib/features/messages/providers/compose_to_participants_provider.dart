import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/messages/repositories/messages_repository.dart';
import 'package:uuid/uuid.dart';

part 'compose_to_participants_provider.g.dart';

class ComposeToParticipantsState {
  const ComposeToParticipantsState({
    required this.selected,
    this.isSending = false,
    this.clientRequestId,
    this.result,
    this.error,
  });

  /// Recipient slugs currently selected on the compose screen.
  final Set<String> selected;
  final bool isSending;
  final String? clientRequestId;
  final SessionMessageResultSchema? result;
  final Object? error;

  ComposeToParticipantsState copyWith({
    Set<String>? selected,
    bool? isSending,
    String? Function()? clientRequestId,
    SessionMessageResultSchema? Function()? result,
    Object? Function()? error,
  }) => ComposeToParticipantsState(
    selected: selected ?? this.selected,
    isSending: isSending ?? this.isSending,
    clientRequestId: clientRequestId != null
        ? clientRequestId()
        : this.clientRequestId,
    result: result != null ? result() : this.result,
    error: error != null ? error() : this.error,
  );
}

@riverpod
class ComposeToParticipantsNotifier extends _$ComposeToParticipantsNotifier {
  var _didSeed = false;

  @override
  ComposeToParticipantsState build(String sessionSlug) =>
      const ComposeToParticipantsState(selected: {});

  /// Applies the initial all-selected Figma state once without overwriting
  /// choices the user has already made.
  void seedRecipients(Iterable<String> slugs) {
    if (_didSeed) return;
    _didSeed = true;
    state = state.copyWith(selected: Set<String>.from(slugs));
  }

  void toggleRecipient(String slug) {
    final updated = Set<String>.from(state.selected);
    if (!updated.add(slug)) updated.remove(slug);
    state = state.copyWith(selected: updated, error: () => null);
  }

  Future<SessionMessageResultSchema?> send(String message) async {
    final text = message.trim();
    if (text.isEmpty || state.selected.isEmpty || state.isSending) return null;

    final requestId = state.clientRequestId ?? const Uuid().v4();
    state = state.copyWith(
      isSending: true,
      clientRequestId: () => requestId,
      error: () => null,
      result: () => null,
    );
    try {
      final result = await ref
          .read(messagesRepositoryProvider)
          .sendSessionMessage(
            sessionSlug,
            recipientSlugs: state.selected.toList(growable: false),
            text: text,
            clientRequestId: requestId,
          );
      state = state.copyWith(
        isSending: false,
        result: () => result,
        error: () => null,
      );
      return result;
    } catch (error) {
      state = state.copyWith(isSending: false, error: () => error);
      return null;
    }
  }
}
