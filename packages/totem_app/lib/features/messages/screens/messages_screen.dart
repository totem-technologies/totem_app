import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_app/features/messages/widgets/chat_card.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/messages/models/conversation.dart';
import 'package:totem_core/features/messages/providers/conversations_provider.dart';
import 'package:totem_core/features/messages/providers/messaging_sync_coordinator.dart';
import 'package:totem_core/features/messages/repositories/messages_repository.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/widgets/error_screen.dart';
import 'package:totem_core/shared/widgets/loading_indicator.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    ref.read(messagingSyncCoordinatorProvider).setInboxVisible(true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    ref.read(messagingSyncCoordinatorProvider).setInboxVisible(false);
    super.dispose();
  }

  Future<void> _refresh() => ref.read(conversationsProvider.notifier).refresh();

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(ref.read(conversationsProvider.notifier).search(query));
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncInbox = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceCard,
        title: const Text('Messages'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 20.0),
            child: Semantics(
              button: true,
              label: 'New message',
              child: InkWell(
                onTap: () => context.push(RouteNames.newMessage),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppTheme.messagePurple,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: AppTheme.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: asyncInbox.when(
        loading: LoadingIndicator.new,
        error: (error, stack) {
          return ErrorScreen(
            error: error,
            showHomeButton: false,
            onRetry: _refresh,
          );
        },
        data: (inbox) {
          if (inbox.searchError != null) {
            return _SearchError(
              onRetry: () => ref
                  .read(conversationsProvider.notifier)
                  .search(inbox.query, force: true),
            );
          }

          if (inbox.conversations.isEmpty) {
            if (inbox.query.isEmpty) {
              return const _EmptyState();
            } else {
              return const _NoSearchResults();
            }
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 240) {
                ref.read(conversationsProvider.notifier).loadMore();
              }
              return false;
            },
            child: RefreshIndicator.adaptive(
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        20,
                        18,
                        20,
                        18,
                      ),
                      child: TextField(
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search messages',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: inbox.isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator.adaptive(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                          filled: true,
                          fillColor: AppTheme.messageSearchBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _ConversationList(
                    conversations: inbox.conversations,
                    isLoadingMore: inbox.isLoadingMore,
                    loadMoreError: inbox.loadMoreError,
                    onLoadMore: () =>
                        ref.read(conversationsProvider.notifier).loadMore(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('No conversations match your search.'));
}

class _SearchError extends StatelessWidget {
  const _SearchError({required this.onRetry});

  final AsyncCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: onRetry,
      child: const Text('Could not search messages. Try again.'),
    ),
  );
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipients = ref.watch(
      recipientDirectoryProvider(RecipientDirectoryKind.keepers),
    );
    return recipients.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (_, _) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(
            recipientDirectoryProvider(RecipientDirectoryKind.keepers),
          ),
          child: const Text('Could not load recommended keepers. Try again.'),
        ),
      ),
      data: (state) {
        final keepers = state.directory.keepers;
        if (keepers.isEmpty) {
          return const Center(
            child: Text('No keepers are available to message right now.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const Text(
              'Start a conversation',
              style: TextStyle(
                color: AppTheme.textHeading,
                fontSize: 21,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Recommended Keepers for you',
              style: TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            for (final keeper in keepers)
              _RecommendedKeeperRow(
                keeper: keeper,
                onTap: () =>
                    _openConversation(context, ref, keeper.profile.slug),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openConversation(
    BuildContext context,
    WidgetRef ref,
    String recipientSlug,
  ) async {
    try {
      final conversation = await ref
          .read(messagesRepositoryProvider)
          .openConversation(recipientSlug);
      ref.read(conversationsProvider.notifier).upsert(conversation);
      if (context.mounted) {
        context.push(RouteNames.messageThread(conversation.id));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This keeper is unavailable.')),
        );
      }
    }
  }
}

class _RecommendedKeeperRow extends StatelessWidget {
  const _RecommendedKeeperRow({required this.keeper, required this.onTap});

  final KeeperRecipientSchema keeper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(child: Text(keeper.profile.name.characters.first)),
    title: Text(keeper.profile.name),
    trailing: FilledButton(onPressed: onTap, child: const Text('Message')),
  );
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.conversations,
    required this.isLoadingMore,
    required this.loadMoreError,
    required this.onLoadMore,
  });

  final List<Conversation> conversations;
  final bool isLoadingMore;
  final Object? loadMoreError;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 20),
    sliver: SliverList.separated(
      itemCount:
          conversations.length +
          (isLoadingMore || loadMoreError != null ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == conversations.length) {
          if (loadMoreError != null) {
            return TextButton(
              onPressed: onLoadMore,
              child: const Text('Retry loading more'),
            );
          }
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        final conversation = conversations[index];
        final lastMessage = conversation.lastMessage;
        final preview = lastMessage == null
            ? ''
            : lastMessage.isOwn
            ? 'You: ${lastMessage.text}'
            : lastMessage.text;
        return ChatCard(
          name: conversation.peer.name ?? 'Unknown',
          lastMessage: preview,
          timestamp: conversation.updatedAt,
          avatarSeed: conversation.peer.profileAvatarSeed,
          unreadCount: conversation.unreadCount,
          isOwnLastMessage: lastMessage?.isOwn ?? false,
          onTap: () => context.push(RouteNames.messageThread(conversation.id)),
        );
      },
    ),
  );
}
