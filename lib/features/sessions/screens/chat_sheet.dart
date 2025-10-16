import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider;
import 'package:livekit_components/livekit_components.dart';
// package:livekit_components depends on package:provider, but we don't. We need
// [ChangeNotifierProvider] from package:provider to pass the RoomContext to the
// chat sheet, so we import it directly here.
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart' show ChangeNotifierProvider;
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/keeper/screens/keeper_profile_screen.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

Future<void> showSessionChatSheet(
  BuildContext context,
  RoomContext roomCtx,
  EventDetailSchema event,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    builder: (context) {
      return ChangeNotifierProvider<RoomContext>.value(
        value: roomCtx,
        child: SessionChatSheet(event: event),
      );
    },
  );
}

class SessionChatSheet extends ConsumerStatefulWidget {
  const SessionChatSheet({required this.event, super.key});

  final EventDetailSchema event;

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
    final auth = ref.watch(authControllerProvider);
    final isKeeper = widget.event.space.author.slug == auth.user?.slug;

    return ChatBuilder(
      builder: (context, enabled, chatCtx, messages) {
        void send() {
          final message = _messageController.text.trim();
          if (message.isNotEmpty) {
            chatCtx.sendMessage(message);
            _messageController.clear();
          }
        }

        return DraggableScrollableSheet(
          maxChildSize: 0.9,
          initialChildSize: 0.75,
          expand: false,
          builder: (context, scrollController) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              // use scaffold to get proper virtual keyboard handling
              body: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isKeeper)
                        const Text(
                          'Only the Keeper can post messages here',
                          style: TextStyle(color: Color(0xFF787D7E)),
                          textAlign: TextAlign.center,
                        ),
                      if (messages.isEmpty)
                        const Padding(
                          padding: EdgeInsetsDirectional.only(top: 20),
                          child: Text(
                            'No messages yet',
                            style: TextStyle(color: Color(0xFF787D7E)),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            controller: scrollController,
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              final isMine =
                                  msg.participant?.identity == auth.user?.email;
                              if (isMine) {
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
                                      msg.message,
                                      style: TextStyle(
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                );
                              } else {
                                return Row(
                                  spacing: 10,
                                  children: [
                                    // TODO(bdlukaa): Only show author avatar
                                    //                for the first message in
                                    //                the sequence.
                                    UserAvatar.fromUserSchema(
                                      widget.event.space.author,
                                      radius: 20,
                                      onTap:
                                          widget.event.space.author.slug != null
                                          ? () {
                                              showKeeperProfileSheet(
                                                context,
                                                widget.event.space.author.slug!,
                                              );
                                            }
                                          : null,
                                    ),
                                    Container(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF3F1E9),
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(16),
                                        ),
                                      ),
                                      padding: const EdgeInsetsDirectional.all(
                                        10,
                                      ),
                                      child: Text(msg.message),
                                    ),
                                  ],
                                );
                              }
                            },
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                          ),
                        ),
                      if (isKeeper)
                        TextField(
                          controller: _messageController,
                          onSubmitted: (_) => send(),
                          textInputAction: TextInputAction.send,
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
