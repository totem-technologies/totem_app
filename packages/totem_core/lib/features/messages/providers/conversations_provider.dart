import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/messages/models/conversation.dart';
import 'package:totem_core/features/messages/repositories/messages_repository.dart';

part 'conversations_provider.g.dart';

class InboxState {
  const InboxState({
    required this.conversations,
    required this.totalUnreadCount,
    this.nextCursor,
    this.syncCursor,
    this.query = '',
    this.isLoadingMore = false,
    this.isSearching = false,
    this.loadMoreError,
    this.searchError,
  });

  final List<Conversation> conversations;
  final int totalUnreadCount;
  final String? nextCursor;
  final String? syncCursor;
  final String query;
  final bool isLoadingMore;
  final bool isSearching;
  final Object? loadMoreError;
  final Object? searchError;

  InboxState copyWith({
    List<Conversation>? conversations,
    int? totalUnreadCount,
    String? Function()? nextCursor,
    String? Function()? syncCursor,
    String? query,
    bool? isLoadingMore,
    bool? isSearching,
    Object? Function()? loadMoreError,
    Object? Function()? searchError,
  }) {
    return InboxState(
      conversations: conversations ?? this.conversations,
      totalUnreadCount: totalUnreadCount ?? this.totalUnreadCount,
      nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
      syncCursor: syncCursor != null ? syncCursor() : this.syncCursor,
      query: query ?? this.query,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSearching: isSearching ?? this.isSearching,
      loadMoreError: loadMoreError != null
          ? loadMoreError()
          : this.loadMoreError,
      searchError: searchError != null ? searchError() : this.searchError,
    );
  }
}

@riverpod
class ConversationsNotifier extends _$ConversationsNotifier {
  var _searchRequestVersion = 0;

  @override
  Future<InboxState> build() async {
    final page = await ref.read(messagesRepositoryProvider).getConversations();
    return InboxState(
      conversations: _mergeConversations(const [], page.items),
      nextCursor: page.nextCursor,
      syncCursor: page.nextCursor,
      totalUnreadCount: page.totalUnreadCount,
    );
  }

  /// Merges only changed inbox summaries; it never reloads already loaded pages.
  Future<void> refresh() async {
    final current = state.value;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    if (current.query.isNotEmpty) {
      await search(current.query, force: true);
      return;
    }
    final page = await ref
        .read(messagesRepositoryProvider)
        .syncConversations(since: current.syncCursor);
    state = AsyncData(
      current.copyWith(
        conversations: _mergeConversations(current.conversations, page.items),
        syncCursor: () => page.nextCursor ?? current.syncCursor,
        totalUnreadCount: page.totalUnreadCount,
      ),
    );
  }

  Future<void> search(String query, {bool force = false}) async {
    final normalizedQuery = query.trim();
    final current = state.value;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    if (!force && normalizedQuery == current.query) return;

    final requestVersion = ++_searchRequestVersion;
    state = AsyncData(
      current.copyWith(
        query: normalizedQuery,
        isSearching: true,
        searchError: () => null,
        loadMoreError: () => null,
      ),
    );
    try {
      final page = await ref
          .read(messagesRepositoryProvider)
          .getConversations(
            query: normalizedQuery.isEmpty ? null : normalizedQuery,
          );
      if (requestVersion != _searchRequestVersion) return;
      state = AsyncData(
        InboxState(
          conversations: _mergeConversations(const [], page.items),
          nextCursor: page.nextCursor,
          syncCursor: page.nextCursor,
          query: normalizedQuery,
          totalUnreadCount: page.totalUnreadCount,
        ),
      );
    } catch (error) {
      if (requestVersion != _searchRequestVersion) return;
      state = AsyncData(
        current.copyWith(
          query: normalizedQuery,
          isSearching: false,
          searchError: () => error,
        ),
      );
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    final cursor = current?.nextCursor;
    if (current == null || cursor == null || current.isLoadingMore) return;

    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreError: () => null),
    );
    try {
      final page = await ref
          .read(messagesRepositoryProvider)
          .getConversations(
            cursor: cursor,
            query: current.query.isEmpty ? null : current.query,
          );
      state = AsyncData(
        current.copyWith(
          conversations: _mergeConversations(current.conversations, page.items),
          nextCursor: () => page.nextCursor,
          totalUnreadCount: page.totalUnreadCount,
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

  void markReadLocally(String conversationId) {
    final current = state.value;
    if (current == null) return;
    final unreadCount = current.conversations
        .where((conversation) => conversation.id == conversationId)
        .fold(0, (total, conversation) => total + conversation.unreadCount);
    state = AsyncData(
      current.copyWith(
        conversations: current.conversations
            .map(
              (conversation) => conversation.id == conversationId
                  ? conversation.copyWith(unreadCount: 0)
                  : conversation,
            )
            .toList(growable: false),
        totalUnreadCount: (current.totalUnreadCount - unreadCount).clamp(
          0,
          1 << 31,
        ),
      ),
    );
  }

  void upsert(Conversation conversation) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        conversations: _mergeConversations(current.conversations, [
          conversation,
        ]),
      ),
    );
  }
}

@riverpod
Future<Conversation> conversationById(Ref ref, String conversationId) {
  return ref.watch(messagesRepositoryProvider).getConversation(conversationId);
}

class RecipientDirectoryState {
  const RecipientDirectoryState({
    required this.directory,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final RecipientDirectorySchema directory;
  final bool isLoadingMore;
  final Object? loadMoreError;

  RecipientDirectoryState copyWith({
    RecipientDirectorySchema? directory,
    bool? isLoadingMore,
    Object? Function()? loadMoreError,
  }) => RecipientDirectoryState(
    directory: directory ?? this.directory,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreError: loadMoreError != null ? loadMoreError() : this.loadMoreError,
  );
}

@riverpod
class RecipientDirectoryNotifier extends _$RecipientDirectoryNotifier {
  var _query = '';
  var _requestVersion = 0;

  @override
  Future<RecipientDirectoryState> build(RecipientDirectoryKind kind) async {
    final directory = await ref
        .read(messagesRepositoryProvider)
        .getRecipients(kind: kind);
    return RecipientDirectoryState(directory: directory);
  }

  Future<void> search(String query) async {
    final normalized = query.trim();
    if (normalized == _query && state.hasValue) return;
    _query = normalized;
    final version = ++_requestVersion;
    final previous = state.value;
    state = previous == null ? const AsyncLoading() : AsyncData(previous);
    try {
      final directory = await ref
          .read(messagesRepositoryProvider)
          .getRecipients(
            kind: kind,
            query: normalized.isEmpty ? null : normalized,
          );
      if (version == _requestVersion) {
        state = AsyncData(RecipientDirectoryState(directory: directory));
      }
    } catch (error, stackTrace) {
      if (version == _requestVersion) {
        state = previous == null
            ? AsyncError(error, stackTrace)
            : AsyncData(previous.copyWith(loadMoreError: () => error));
      }
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    final cursor = current?.directory.nextCursor;
    if (current == null || cursor == null || current.isLoadingMore) return;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreError: () => null),
    );
    try {
      final incoming = await ref
          .read(messagesRepositoryProvider)
          .getRecipients(
            kind: kind,
            query: _query.isEmpty ? null : _query,
            cursor: cursor,
          );
      state = AsyncData(
        RecipientDirectoryState(
          directory: _mergeRecipientDirectories(current.directory, incoming),
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreError: () => error),
      );
    }
  }
}

class SessionParticipantsState {
  const SessionParticipantsState({
    required this.participants,
    this.nextCursor,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<SessionParticipantSchema> participants;
  final String? nextCursor;
  final bool isLoadingMore;
  final Object? loadMoreError;

  SessionParticipantsState copyWith({
    List<SessionParticipantSchema>? participants,
    String? Function()? nextCursor,
    bool? isLoadingMore,
    Object? Function()? loadMoreError,
  }) => SessionParticipantsState(
    participants: participants ?? this.participants,
    nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreError: loadMoreError != null ? loadMoreError() : this.loadMoreError,
  );
}

@riverpod
class SessionMessageParticipantsNotifier
    extends _$SessionMessageParticipantsNotifier {
  @override
  Future<SessionParticipantsState> build(String sessionSlug) async {
    final page = await ref
        .read(messagesRepositoryProvider)
        .getSessionParticipants(sessionSlug);
    return SessionParticipantsState(
      participants: _mergeSessionParticipants(const [], page.items),
      nextCursor: page.nextCursor,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        current.nextCursor == null ||
        current.isLoadingMore) {
      return;
    }
    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreError: () => null),
    );
    try {
      final page = await ref
          .read(messagesRepositoryProvider)
          .getSessionParticipants(sessionSlug, cursor: current.nextCursor);
      state = AsyncData(
        current.copyWith(
          participants: _mergeSessionParticipants(
            current.participants,
            page.items,
          ),
          nextCursor: () => page.nextCursor,
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
}

List<Conversation> _mergeConversations(
  List<Conversation> existing,
  List<Conversation> incoming,
) {
  final byId = <String, Conversation>{
    for (final conversation in existing) conversation.id: conversation,
    for (final conversation in incoming) conversation.id: conversation,
  };
  final result = byId.values.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return result;
}

RecipientDirectorySchema _mergeRecipientDirectories(
  RecipientDirectorySchema existing,
  RecipientDirectorySchema incoming,
) => RecipientDirectorySchema(
  kind: incoming.kind,
  keepers: _dedupeBySlug([...existing.keepers, ...incoming.keepers]),
  participants: _dedupeParticipants([
    ...existing.participants,
    ...incoming.participants,
  ]),
  nextCursor: incoming.nextCursor,
);

List<KeeperRecipientSchema> _dedupeBySlug(List<KeeperRecipientSchema> items) {
  final bySlug = <String, KeeperRecipientSchema>{
    for (final item in items) item.profile.slug: item,
  };
  return bySlug.values.toList(growable: false);
}

List<ParticipantRecipientSchema> _dedupeParticipants(
  List<ParticipantRecipientSchema> items,
) {
  final bySlug = <String, ParticipantRecipientSchema>{
    for (final item in items) item.profile.slug: item,
  };
  return bySlug.values.toList(growable: false);
}

List<SessionParticipantSchema> _mergeSessionParticipants(
  List<SessionParticipantSchema> existing,
  List<SessionParticipantSchema> incoming,
) {
  final bySlug = <String, SessionParticipantSchema>{
    for (final item in existing) item.profile.slug: item,
    for (final item in incoming) item.profile.slug: item,
  };
  return bySlug.values.toList(growable: false);
}
