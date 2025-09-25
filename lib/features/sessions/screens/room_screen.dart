import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/screens/chat_sheet.dart';
import 'package:totem_app/features/sessions/screens/loading_screen.dart';
import 'package:totem_app/features/sessions/screens/my_turn.dart';
import 'package:totem_app/features/sessions/screens/not_my_turn.dart';
import 'package:totem_app/features/sessions/screens/session_ended.dart';
import 'package:totem_app/features/sessions/services/livekit_service.dart';
import 'package:totem_app/features/sessions/widgets/action_bar.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/emoji_bar.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/popups.dart';

class VideoRoomScreen extends ConsumerStatefulWidget {
  const VideoRoomScreen({
    required this.roomName,
    required this.token,
    required this.cameraEnabled,
    required this.micEnabled,
    required this.event,
    super.key,
  });

  final String roomName;
  final String token;
  final bool cameraEnabled;
  final bool micEnabled;
  final EventDetailSchema event;

  @override
  ConsumerState<VideoRoomScreen> createState() => _VideoRoomScreenState();
}

class _VideoRoomScreenState extends ConsumerState<VideoRoomScreen> {
  Map<String, GlobalKey> participantKeys = {};
  GlobalKey getParticipantKey(String identity) {
    return participantKeys.putIfAbsent(identity, GlobalKey.new);
  }

  var _showEmojiPicker = false;

  void _onEmojiReceived(String userIdentity, String emoji) {
    final userKey = participantKeys[userIdentity];
    if (userKey != null && userKey.currentContext != null) {
      displayReaction(
        context,
        userKey.currentContext!,
        emoji,
      );
    }
  }

  bool _chatSheetOpen = false;
  bool _hasPendingChatMessages = false;
  void _onChatMessageReceived(String userIdentity, String message) {
    setState(() => _hasPendingChatMessages = !_chatSheetOpen);
    showNotificationPopup(
      context,
      icon: TotemIcons.chat,
      title: 'New message',
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(
      sessionServiceProvider(
        SessionOptions(
          token: widget.token,
          cameraEnabled: widget.cameraEnabled,
          microphoneEnabled: widget.micEnabled,
          onEmojiReceived: _onEmojiReceived,
          onMessageReceived: _onChatMessageReceived,
        ),
      ),
    );

    return Scaffold(
      body: RoomBackground(
        child: LivekitRoom(
          roomContext: session.room,
          builder: (context, roomCtx) {
            final room = roomCtx.room;

            switch (room.connectionState) {
              case ConnectionState.connecting:
              case ConnectionState.reconnecting:
                return const LoadingRoomScreen();
              case ConnectionState.disconnected:
                return SessionEndedScreen(
                  event: widget.event,
                );
              case ConnectionState.connected:
                if (!session.isMyTurn) {
                  return MyTurn(
                    actionBar: buildActionBar(session),
                    getParticipantKey: getParticipantKey,
                  );
                } else {
                  return NotMyTurn(
                    actionBar: buildActionBar(session),
                    getParticipantKey: getParticipantKey,
                  );
                }
            }
          },
        ),
      ),
    );
  }

  Widget buildActionBar(
    LiveKitService session,
  ) {
    return Builder(
      builder: (context) {
        final roomCtx = session.room;
        final user = roomCtx.localParticipant;
        return ActionBar(
          children: [
            MediaDeviceSelectButton(
              builder: (context, roomCtx, deviceCtx) {
                return ActionBarButton(
                  active: roomCtx.microphoneOpened,
                  onPressed: () {
                    if (roomCtx.microphoneOpened) {
                      deviceCtx.disableMicrophone();
                    } else {
                      deviceCtx.enableMicrophone();
                    }
                  },
                  child: TotemIcon(
                    roomCtx.microphoneOpened
                        ? TotemIcons.microphoneOn
                        : TotemIcons.microphoneOff,
                  ),
                );
              },
            ),
            MediaDeviceSelectButton(
              builder: (context, roomCtx, deviceCtx) {
                return ActionBarButton(
                  active: roomCtx.cameraOpened,
                  onPressed: () {
                    if (roomCtx.cameraOpened) {
                      deviceCtx.disableCamera();
                    } else {
                      deviceCtx.enableCamera();
                    }
                  },
                  child: TotemIcon(
                    roomCtx.cameraOpened
                        ? TotemIcons.cameraOn
                        : TotemIcons.cameraOff,
                  ),
                );
              },
            ),
            if (!session.isMyTurn)
              Builder(
                builder: (button) {
                  return ActionBarButton(
                    active: _showEmojiPicker,
                    onPressed: () async {
                      setState(() => _showEmojiPicker = true);
                      final emoji = await showEmojiBar(
                        button,
                        context,
                      );
                      if (emoji != null && emoji.isNotEmpty) {
                        session.sendEmoji(emoji);
                        if (user?.identity != null) {
                          _onEmojiReceived(user!.identity, emoji);
                        }
                      }
                      if (mounted) {
                        setState(() => _showEmojiPicker = false);
                      }
                    },
                    child: const TotemIcon(TotemIcons.reaction),
                  );
                },
              ),
            ActionBarButton(
              active: _chatSheetOpen,
              onPressed: () async {
                setState(() {
                  _hasPendingChatMessages = false;
                  _chatSheetOpen = true;
                });
                await showSessionChatSheet(
                  context,
                  roomCtx,
                  widget.event,
                );
                if (mounted) {
                  setState(() => _chatSheetOpen = false);
                }
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const TotemIcon(TotemIcons.chat),
                  if (_hasPendingChatMessages)
                    Container(
                      height: 4,
                      width: 4,
                      decoration: const BoxDecoration(
                        color: AppTheme.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 40,
                maxHeight: 40,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  // TODO(bdlukaa): Show more options
                },
                icon: const TotemIcon(
                  TotemIcons.more,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
