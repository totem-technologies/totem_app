import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'compose_to_participants_provider.g.dart';

class ComposeToParticipantsState {
  const ComposeToParticipantsState({
    required this.selected,
    this.isSending = false,
  });

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

@riverpod
class ComposeToParticipantsNotifier extends _$ComposeToParticipantsNotifier {
  @override
  ComposeToParticipantsState build(List<String> participantIds) =>
      ComposeToParticipantsState(selected: Set.from(participantIds));

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
  Future<bool> send(String message) async {
    state = state.copyWith(isSending: true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    state = state.copyWith(isSending: false);
    return true;
  }
}
