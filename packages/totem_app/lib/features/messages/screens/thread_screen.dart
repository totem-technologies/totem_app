import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/features/auth/services/notifications_service.dart';
import 'package:intl/intl.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/messages/models/conversation.dart';
import 'package:totem_core/features/messages/models/message.dart';
import 'package:totem_core/features/messages/providers/conversations_provider.dart';
import 'package:totem_core/features/messages/providers/messaging_sync_coordinator.dart';
import 'package:totem_core/features/messages/providers/thread_provider.dart';
import 'package:totem_core/shared/widgets/user_avatar.dart';

import '../widgets/day_separator.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_bar.dart';

class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  String? _lastReadMessageId;

  @override
  void initState() {
    super.initState();
    NotificationsService.instance.visibleConversationId = widget.conversationId;
    ref
        .read(messagingSyncCoordinatorProvider)
        .setThreadVisible(widget.conversationId, true);
  }

  @override
  void dispose() {
    if (NotificationsService.instance.visibleConversationId ==
        widget.conversationId) {
      NotificationsService.instance.visibleConversationId = null;
    }
    ref
        .read(messagingSyncCoordinatorProvider)
        .setThreadVisible(widget.conversationId, false);
    super.dispose();
  }

  Future<void> _refresh() =>
      ref.read(threadProvider(widget.conversationId).notifier).fetchNewer();

  void _markReadAfterVisible(ThreadState thread) {
    final latestIncoming = thread.messages
        .where((message) => !message.isOwn)
        .firstOrNull;
    if (latestIncoming == null || latestIncoming.id == _lastReadMessageId) {
      return;
    }
    _lastReadMessageId = latestIncoming.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        ref.read(threadProvider(widget.conversationId).notifier).markRead(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncConversation = ref.watch(
      conversationByIdProvider(widget.conversationId),
    );

    return asyncConversation.when(
      loading: () => const Scaffold(
        backgroundColor: AppTheme.cream,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const _UnavailableConversation(),
      data: (conversation) {
        return _ThreadBody(
          conversation: conversation,
          conversationId: widget.conversationId,
          onMessagesVisible: _markReadAfterVisible,
          onRefresh: _refresh,
        );
      },
    );
  }
}

class _ThreadBody extends ConsumerWidget {
  const _ThreadBody({
    required this.conversation,
    required this.conversationId,
    required this.onMessagesVisible,
    required this.onRefresh,
  });

  final Conversation conversation;
  final String conversationId;
  final ValueChanged<ThreadState> onMessagesVisible;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncThread = ref.watch(threadProvider(conversationId));

    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: Column(
        children: [
          _ThreadHeader(conversation: conversation),
          Expanded(
            child: asyncThread.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _ThreadError(onRetry: onRefresh),
              data: (thread) {
                onMessagesVisible(thread);
                if (thread.messages.isEmpty) return const _ThreadEmptyState();
                return _MessageList(
                  thread: thread,
                  onLoadMore: () => ref
                      .read(threadProvider(conversationId).notifier)
                      .loadMore(),
                  onRetry: (message) => ref
                      .read(threadProvider(conversationId).notifier)
                      .retry(message),
                );
              },
            ),
          ),
          MessageInputBar(
            isSending: asyncThread.asData?.value.isSending ?? false,
            onSend: (text) async {
              final sent = await ref
                  .read(threadProvider(conversationId).notifier)
                  .send(text);
              return sent;
            },
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.thread,
    required this.onLoadMore,
    required this.onRetry,
  });

  final ThreadState thread;
  final VoidCallback onLoadMore;
  final ValueChanged<Message> onRetry;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 200) onLoadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () async => onLoadMore(),
        child: ListView.builder(
          reverse: true,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          itemCount: thread.messages.length + 1,
          itemBuilder: (context, index) {
            if (index == thread.messages.length) {
              if (thread.isLoadingMore) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (thread.loadMoreError != null) {
                return TextButton(
                  onPressed: onLoadMore,
                  child: const Text('Retry loading older messages'),
                );
              }
              return const SizedBox.shrink();
            }
            final message = thread.messages[index];
            final olderMessage = index + 1 < thread.messages.length
                ? thread.messages[index + 1]
                : null;
            final showsDay =
                olderMessage == null ||
                !_isSameDay(message.sentAt, olderMessage.sentAt);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 19),
                  child: MessageBubble(
                    text: message.text,
                    timestamp: DateFormat.jm().format(message.sentAt),
                    isOwn: message.isOwn,
                    status: message.status,
                    onRetry: () => onRetry(message),
                  ),
                ),
                if (showsDay)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 19),
                    child: DaySeparator(
                      label: DateFormat.MMMEd().format(message.sentAt),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _ThreadEmptyState extends StatelessWidget {
  const _ThreadEmptyState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 40, color: AppTheme.messagePurple),
          SizedBox(height: 12),
          Text(
            'Start your conversation',
            style: TextStyle(
              color: AppTheme.textHeading,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Send a message to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ],
      ),
    ),
  );
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final peer = conversation.peer;
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      color: AppTheme.surfaceCard,
      padding: EdgeInsetsDirectional.only(top: topPadding),
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: AppTheme.textHeading,
                ),
              ),
              const SizedBox(width: 10),
              UserAvatar.custom(
                seed: peer.profileAvatarSeed,
                radius: 23,
                borderWidth: 0,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  peer.name ?? 'Unknown',
                  style: const TextStyle(
                    color: AppTheme.textHeading,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadError extends StatelessWidget {
  const _ThreadError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onRetry,
        child: const Text('Could not load messages. Try again.'),
      ),
    );
  }
}

class _UnavailableConversation extends StatelessWidget {
  const _UnavailableConversation();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'This conversation is no longer available.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
