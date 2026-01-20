import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/api/models/session_detail_schema.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/keeper/screens/keeper_profile_screen.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

Future<void> showSessionChatSheet(
  BuildContext context,
  SessionDetailSchema event,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    useSafeArea: true,
    backgroundColor: Colors.white,
    builder: (context) {
      return SessionChatSheet(event: event);
    },
  );
}

class SessionChatSheet extends ConsumerStatefulWidget {
  const SessionChatSheet({required this.event, super.key});

  final SessionDetailSchema event;

  @override
  ConsumerState<SessionChatSheet> createState() => _SessionChatSheetState();
}

class _SessionChatSheetState extends ConsumerState<SessionChatSheet> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(
      authControllerProvider.select((auth) => auth.user),
    );
    final isKeeper = widget.event.space.author.slug == user?.slug;

    const fastMessages = [
      'Welcome! 🙏',
      'Please mute your mic',
      'Thank you for sharing',
      "Let's begin",
      'Please unmute to share',
      'Take your time',
    ];

    return ChatBuilder(
      builder: (context, enabled, chatCtx, messages) {
        final listedMessages = List<ChatMessage>.from(messages.reversed);
        return DraggableScrollableSheet(
          maxChildSize: 0.9,
          initialChildSize: 0.75,
          expand: false,
          builder: (context, scrollController) {
            Future<void> send() async {
              final message = _messageController.text.trim();
              if (message.isNotEmpty) {
                chatCtx.sendMessage(message);
                _messageController.clear();
              }
              await scrollController.animateTo(
                scrollController.position.maxScrollExtent + 80,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }

            return Scaffold(
              backgroundColor: Colors.transparent,
              // use scaffold to get proper virtual keyboard padding handling
              body: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 14),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      if (!isKeeper)
                        const Padding(
                          padding: EdgeInsetsDirectional.only(
                            bottom: 8,
                            start: 20,
                            end: 20,
                          ),
                          child: Text(
                            'Only the Keeper can post messages here',
                            style: TextStyle(color: Color(0xFF787D7E)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (messages.isEmpty) ...[
                        const Padding(
                          padding: EdgeInsetsDirectional.only(
                            top: 20,
                            bottom: 8,
                            start: 20,
                            end: 20,
                          ),
                          child: Text(
                            'No messages yet',
                            style: TextStyle(color: Color(0xFF787D7E)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const Spacer(),
                      ] else
                        Expanded(
                          child: ListView.separated(
                            padding: EdgeInsetsDirectional.only(
                              bottom: isKeeper ? 8 : 0,
                              start: 20,
                              end: 20,
                            ),
                            reverse: true,
                            controller: scrollController,
                            itemCount: listedMessages.length,
                            itemBuilder: (context, index) {
                              final msg = listedMessages[index];
                              final isMine =
                                  msg.participant?.identity == user?.email;
                              if (isMine) {
                                return MyChatBubble(message: msg);
                              } else {
                                final showAvatar =
                                    index == 0 ||
                                    listedMessages[(listedMessages.length -
                                                    index)
                                                .clamp(
                                                  0,
                                                  listedMessages.length - 1,
                                                )]
                                            .participant
                                            ?.identity !=
                                        msg.participant?.identity;
                                return OtherChatBubble(
                                  showAvatar: showAvatar,
                                  message: msg,
                                  event: widget.event,
                                );
                              }
                            },
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                          ),
                        ),
                      if (isKeeper) ...[
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: 8,
                            start: 20,
                            end: 20,
                          ),
                          child: Text(
                            'Long press to send a quick message',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(top: 8),
                          child: SizedBox(
                            height: 36,
                            child: ListView.separated(
                              padding: const EdgeInsetsDirectional.only(
                                start: 20,
                                end: 20,
                              ),
                              scrollDirection: Axis.horizontal,
                              itemCount: fastMessages.length,
                              itemBuilder: (context, index) {
                                final label = fastMessages[index];
                                return _QuickMessageChip(
                                  label: label,
                                  onSend: () => chatCtx.sendMessage(label),
                                );
                              },
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: 8,
                            start: 20,
                            end: 20,
                          ),
                          child: TextField(
                            controller: _messageController,
                            onSubmitted: (_) => send(),
                            textInputAction: TextInputAction.send,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Message',
                              border: const OutlineInputBorder(),
                              suffixIcon: Container(
                                margin: const EdgeInsetsDirectional.only(
                                  end: 8,
                                  top: 6,
                                  bottom: 6,
                                ),
                                constraints: const BoxConstraints(
                                  maxHeight: 42,
                                  maxWidth: 42,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(16),
                                  ),
                                ),
                                child: IconButton(
                                  icon: const TotemIcon(
                                    TotemIcons.send,
                                    size: 20,
                                  ),
                                  color: theme.colorScheme.onPrimary,
                                  onPressed: send,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class OtherChatBubble extends StatelessWidget {
  const OtherChatBubble({
    required this.showAvatar,
    required this.message,
    required this.event,
    super.key,
  });

  final bool showAvatar;
  final ChatMessage message;
  final SessionDetailSchema event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAvatar)
          UserAvatar.fromUserSchema(
            event.space.author,
            radius: 20,
            onTap: event.space.author.slug != null
                ? () => showKeeperProfileSheet(
                    context,
                    event.space.author.slug!,
                  )
                : null,
          )
        else
          const SizedBox(width: 40),
        const SizedBox(width: 10),
        Flexible(
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.all(
                Radius.circular(16),
              ),
            ),
            padding: const EdgeInsetsDirectional.all(
              10,
            ),
            child: Text(
              message.message,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MyChatBubble extends StatelessWidget {
  const MyChatBubble({
    required this.message,
    super.key,
  });

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsetsDirectional.only(
          start: 50,
        ),
        padding: const EdgeInsetsDirectional.all(
          10,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.slate,
          borderRadius: BorderRadius.all(
            Radius.circular(16),
          ),
        ),
        child: Text(
          message.message,
          style: TextStyle(
            color: theme.colorScheme.onInverseSurface,
          ),
        ),
      ),
    );
  }
}

Future<void> showKeeperProfileSheet(
  BuildContext context,
  String slug,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    builder: (context) {
      return KeeperProfileSheet(slug: slug);
    },
  );
}

class KeeperProfileSheet extends StatelessWidget {
  const KeeperProfileSheet({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      maxChildSize: 0.8,
      initialChildSize: 0.8,
      expand: false,
      builder: (context, controller) {
        return PrimaryScrollController(
          controller: controller,
          child: KeeperProfileScreen(
            slug: slug,
            showAppBar: false,
          ),
        );
      },
    );
  }
}

class _QuickMessageChip extends StatelessWidget {
  const _QuickMessageChip({
    required this.label,
    required this.onSend,
  });

  final String label;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onLongPress: onSend,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
