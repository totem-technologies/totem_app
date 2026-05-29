import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/features/messages/models/message.dart';
import 'package:totem_core/features/messages/repositories/messages_repository.dart';

part 'thread_provider.g.dart';

@riverpod
class ThreadNotifier extends _$ThreadNotifier {
  @override
  Future<List<Message>> build(String conversationId) =>
      ref.read(messagesRepositoryProvider).getMessages(conversationId);

  Future<void> send(String text) async {
    final repo = ref.read(messagesRepositoryProvider);
    final message = await repo.sendMessage(conversationId, text);
    final current = state.value ?? [];
    state = AsyncData([message, ...current]);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isEmpty) return;
    final repo = ref.read(messagesRepositoryProvider);
    final older = await repo.getMessages(
      conversationId,
      beforeId: current.last.id,
    );
    if (older.isEmpty) return;
    state = AsyncData([...current, ...older]);
  }
}
