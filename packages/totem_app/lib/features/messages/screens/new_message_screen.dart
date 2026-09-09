import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/messages/providers/conversations_provider.dart';
import 'package:totem_core/features/messages/providers/is_current_user_keeper_provider.dart';
import 'package:totem_core/features/messages/repositories/messages_repository.dart';
import 'package:totem_core/shared/router.dart';

class NewMessageScreen extends ConsumerStatefulWidget {
  const NewMessageScreen({super.key});

  @override
  ConsumerState<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends ConsumerState<NewMessageScreen> {
  Timer? _searchDebounce;
  bool _openingConversation = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value, RecipientDirectoryKind kind) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(recipientDirectoryProvider(kind).notifier).search(value);
    });
  }

  Future<void> _openConversation(String recipientSlug) async {
    if (_openingConversation) return;
    setState(() => _openingConversation = true);
    try {
      final conversation = await ref
          .read(messagesRepositoryProvider)
          .openConversation(recipientSlug);
      ref.read(conversationsProvider.notifier).upsert(conversation);
      if (mounted) {
        // Replace the picker: back returns to Messages, not to a stale search.
        context.pushReplacement(RouteNames.messageThread(conversation.id));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This person is unavailable to message.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingConversation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKeeper = ref.watch(isCurrentMessagingUserKeeperProvider);
    final kind = isKeeper
        ? RecipientDirectoryKind.participants
        : RecipientDirectoryKind.keepers;
    final recipients = ref.watch(recipientDirectoryProvider(kind));

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceCard,
        title: const Text('New Message'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: TextField(
              onChanged: (value) => _onSearchChanged(value, kind),
              decoration: InputDecoration(
                hintText: isKeeper ? 'Search participants' : 'Search keepers',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppTheme.messageSearchBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: recipients.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () =>
                      ref.invalidate(recipientDirectoryProvider(kind)),
                  child: const Text('Could not load recipients. Try again.'),
                ),
              ),
              data: (state) => _RecipientList(
                directory: state.directory,
                isKeeper: isKeeper,
                isLoadingMore: state.isLoadingMore,
                loadMoreError: state.loadMoreError,
                isOpeningConversation: _openingConversation,
                onLoadMore: () => ref
                    .read(recipientDirectoryProvider(kind).notifier)
                    .loadMore(),
                onTap: _openConversation,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientList extends StatelessWidget {
  const _RecipientList({
    required this.directory,
    required this.isKeeper,
    required this.isLoadingMore,
    required this.loadMoreError,
    required this.isOpeningConversation,
    required this.onLoadMore,
    required this.onTap,
  });

  final RecipientDirectorySchema directory;
  final bool isKeeper;
  final bool isLoadingMore;
  final Object? loadMoreError;
  final bool isOpeningConversation;
  final VoidCallback onLoadMore;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final hasRecipients = isKeeper
        ? directory.participants.isNotEmpty
        : directory.keepers.isNotEmpty;
    if (!hasRecipients) {
      return const Center(child: Text('No eligible recipients found.'));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 240) onLoadMore();
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            isKeeper ? 'YOUR SESSION PARTICIPANTS' : 'YOUR KEEPERS',
            style: const TextStyle(
              color: AppTheme.messagePurple,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          if (isKeeper)
            for (final recipient in directory.participants)
              _ParticipantRecipientRow(
                recipient: recipient,
                enabled: !isOpeningConversation && recipient.canStartDirect,
                onTap: onTap,
              )
          else
            for (final recipient in directory.keepers)
              _KeeperRecipientRow(
                recipient: recipient,
                enabled: !isOpeningConversation && recipient.canStartDirect,
                onTap: onTap,
              ),
          if (isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else if (loadMoreError != null)
            TextButton(
              onPressed: onLoadMore,
              child: const Text('Retry loading more'),
            ),
        ],
      ),
    );
  }
}

class _KeeperRecipientRow extends StatelessWidget {
  const _KeeperRecipientRow({
    required this.recipient,
    required this.enabled,
    required this.onTap,
  });

  final KeeperRecipientSchema recipient;
  final bool enabled;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => _RecipientRow(
    name: recipient.profile.name,
    avatarSeed: recipient.profile.profileAvatarSeed,
    enabled: enabled,
    onTap: () => onTap(recipient.profile.slug),
  );
}

class _ParticipantRecipientRow extends StatelessWidget {
  const _ParticipantRecipientRow({
    required this.recipient,
    required this.enabled,
    required this.onTap,
  });

  final ParticipantRecipientSchema recipient;
  final bool enabled;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => _RecipientRow(
    name: recipient.profile.name,
    avatarSeed: recipient.profile.profileAvatarSeed,
    subtitle:
        '${recipient.sessionTitle} · ${DateFormat.MMMd().format(recipient.sessionStart.toLocal())}',
    enabled: enabled,
    onTap: () => onTap(recipient.profile.slug),
  );
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({
    required this.name,
    required this.avatarSeed,
    required this.enabled,
    required this.onTap,
    this.subtitle,
  });

  final String name;
  final String avatarSeed;
  final String? subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    enabled: enabled,
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(child: Text(name.characters.first)),
    title: Text(name),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right),
    onTap: enabled ? onTap : null,
  );
}
