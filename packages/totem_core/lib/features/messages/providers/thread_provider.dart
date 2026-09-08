import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/features/messages/models/message.dart';
import 'package:totem_core/features/messages/providers/conversations_provider.dart';
import 'package:totem_core/features/messages/repositories/messages_repository.dart';
import 'package:uuid/uuid.dart';

part 'thread_provider.g.dart';

class ThreadState {
  const ThreadState({
    required this.messages,
    required this.hasMoreOlder,
    this.oldestCursor,
    this.newestCursor,
    this.isLoadingMore = false,
    this.isSending = false,
    this.loadMoreError,
  });

  /// Newest-first; the screen renders this in chronological order.
  final List<Message> messages;
  final String? oldestCursor;
  final String? newestCursor;
  final bool hasMoreOlder;
  final bool isLoadingMore;
  final bool isSending;
  final Object? loadMoreError;

  ThreadState copyWith({
    List<Message>? messages,
    String? Function()? oldestCursor,
    String? Function()? newestCursor,
    bool? hasMoreOlder,
    bool? isLoadingMore,
    bool? isSending,
    Object? Function()? loadMoreError,
  }) => ThreadState(
    messages: messages ?? this.messages,
    oldestCursor: oldestCursor != null ? oldestCursor() : this.oldestCursor,
    newestCursor: newestCursor != null ? newestCursor() : this.newestCursor,
    hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isSending: isSending ?? this.isSending,
    loadMoreError: loadMoreError != null ? loadMoreError() : this.loadMoreError,
  );
}

@riverpod
class ThreadNotifier extends _$ThreadNotifier {
  @override
  Future<ThreadState> build(String conversationId) async {
    final page = await ref
        .read(messagesRepositoryProvider)
        .getMessages(conversationId);
    final messages = _mergeMessages(const [], page.items);
    return ThreadState(
      messages: messages,
      oldestCursor: page.nextBefore,
      newestCursor: page.nextAfter ?? messages.firstOrNull?.cursor,
      hasMoreOlder: page.hasMore,
    );
  }

  /// Fetches only server messages newer than the known newest cursor.
  Future<void> fetchNewer() async {
    final current = state.value;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    final cursor = current.newestCursor;
    if (cursor == null) return;
    final page = await ref
        .read(messagesRepositoryProvider)
        .getMessages(conversationId, after: cursor);
    final messages = _mergeMessages(current.messages, page.items);
    state = AsyncData(
      current.copyWith(
        messages: messages,
        newestCursor: () =>
            page.nextAfter ?? messages.firstOrNull?.cursor ?? cursor,
      ),
    );
    if (page.items.isNotEmpty) await _refreshConversationSummary();
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        !current.hasMoreOlder ||
        current.isLoadingMore ||
        current.oldestCursor == null) {
      return;
    }

    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreError: () => null),
    );
    try {
      final page = await ref
          .read(messagesRepositoryProvider)
          .getMessages(conversationId, before: current.oldestCursor);
      state = AsyncData(
        current.copyWith(
          messages: _mergeMessages(current.messages, page.items),
          oldestCursor: () => page.nextBefore,
          hasMoreOlder: page.hasMore,
          isLoadingMore: false,
          loadMoreError: () => null,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreError: () => error),
      );
    }
  }

  Future<bool> send(String text, {String? clientMessageId}) {
    final trimmedText = text.trim();
    final current = state.value;
    if (trimmedText.isEmpty || current == null || current.isSending) {
      return Future.value(false);
    }

    final id = clientMessageId ?? const Uuid().v4();
    final pending = Message(
      id: 'pending:$id',
      conversationId: conversationId,
      senderId: 'me',
      text: trimmedText,
      sentAt: DateTime.now(),
      isOwn: true,
      status: MessageStatus.pending,
      clientMessageId: id,
    );
    state = AsyncData(
      current.copyWith(
        messages: _mergeMessages(current.messages, [pending]),
        isSending: true,
      ),
    );

    return _send(trimmedText, id);
  }

  Future<bool> retry(Message message) {
    if (message.status != MessageStatus.failed ||
        message.clientMessageId == null ||
        state.value?.isSending == true) {
      return Future.value(false);
    }
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(
        messages: current.messages
            .map(
              (item) => item.clientMessageId == message.clientMessageId
                  ? item.copyWith(status: MessageStatus.pending)
                  : item,
            )
            .toList(growable: false),
        isSending: true,
      ),
    );
    return _send(message.text, message.clientMessageId!);
  }

  Future<bool> _send(String text, String clientMessageId) async {
    try {
      final canonical = await ref
          .read(messagesRepositoryProvider)
          .sendMessage(conversationId, text, clientMessageId: clientMessageId);
      final current = state.requireValue;
      state = AsyncData(
        current.copyWith(
          messages: _replaceMessage(
            current.messages,
            clientMessageId,
            canonical,
          ),
          newestCursor: () => canonical.cursor ?? current.newestCursor,
          isSending: false,
        ),
      );
      await _refreshConversationSummary();
      return true;
    } catch (_) {
      final current = state.requireValue;
      state = AsyncData(
        current.copyWith(
          messages: current.messages
              .map(
                (item) => item.clientMessageId == clientMessageId
                    ? item.copyWith(status: MessageStatus.failed)
                    : item,
              )
              .toList(growable: false),
          isSending: false,
        ),
      );
      return false;
    }
  }

  Future<void> markRead() async {
    final current = state.value;
    if (current == null) return;
    final newestIncoming = current.messages
        .where((message) => !message.isOwn)
        .firstOrNull;
    if (newestIncoming == null) return;

    ref.read(conversationsProvider.notifier).markReadLocally(conversationId);
    try {
      await ref
          .read(messagesRepositoryProvider)
          .markAsRead(conversationId, newestIncoming.id);
    } catch (_) {
      // Sync is authoritative if the optimistic read marker could not persist.
    }
  }

  Future<void> _refreshConversationSummary() async {
    try {
      final conversation = await ref
          .read(messagesRepositoryProvider)
          .getConversation(conversationId);
      ref.read(conversationsProvider.notifier).upsert(conversation);
    } catch (_) {
      // The next lightweight inbox sync reconciles this summary.
    }
  }
}

List<Message> _mergeMessages(List<Message> existing, List<Message> incoming) {
  final byServerId = <String, Message>{
    for (final message in existing) message.id: message,
  };
  for (final message in incoming) {
    final optimisticKey = message.clientMessageId;
    if (optimisticKey != null) {
      byServerId.removeWhere(
        (_, value) => value.clientMessageId == optimisticKey,
      );
    }
    byServerId[message.id] = message;
  }
  final result = byServerId.values.toList()
    ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
  return result;
}

List<Message> _replaceMessage(
  List<Message> messages,
  String clientMessageId,
  Message canonical,
) => _mergeMessages(
  messages
      .where((message) => message.clientMessageId != clientMessageId)
      .toList(growable: false),
  [canonical],
);
