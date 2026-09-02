import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'compose_to_participants_provider.g.dart';

class ComposeToParticipantsState {
  const ComposeToParticipantsState({
    required this.selected,
    this.isSending = false,
  });

  /// Recipient ids currently checked on the compose screen.
  ///
  /// Ids (not display names) so two people named "Emily" do not collide once
  /// this is wired to real session participants.
  final Set<String> selected;
  final bool isSending;

  ComposeToParticipantsState copyWith({
    Set<String>? selected,
    bool? isSending,
  }) => ComposeToParticipantsState(
    selected: selected ?? this.selected,
    isSending: isSending ?? this.isSending,
  );
}

/// Compose state for broadcasting a message to a session's participants.
///
/// The family is keyed by [sessionSlug] so selection survives rebuilds even
/// when the recipient list is a freshly-allocated `List` from a future
/// backend provider. Do not key on the list itself — that would reset the
/// notifier on every rebuild.
@riverpod
class ComposeToParticipantsNotifier extends _$ComposeToParticipantsNotifier {
  var _didSeed = false;

  @override
  ComposeToParticipantsState build(String sessionSlug) =>
      const ComposeToParticipantsState(selected: {});

  /// Marks every [ids] entry selected the first time the compose screen
  /// loads. Later calls are ignored so chip toggles stay intact.
  void seedRecipients(Iterable<String> ids) {
    if (_didSeed) return;
    _didSeed = true;
    state = state.copyWith(selected: Set<String>.from(ids));
  }

  void toggleRecipient(String id) {
    final updated = Set<String>.from(state.selected);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    state = state.copyWith(selected: updated);
  }

  // TODO(backend): replace with real bulk-message API call when endpoint ships.
  // The mock always succeeds; `_SendResultDialog`'s error branch is waiting
  // on that endpoint before it can be exercised.
  Future<bool> send(String message) async {
    state = state.copyWith(isSending: true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    state = state.copyWith(isSending: false);
    return true;
  }
}
