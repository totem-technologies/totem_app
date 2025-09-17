import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/screens/chat_sheet.dart';
import 'package:totem_app/features/sessions/screens/loading_screen.dart';
import 'package:totem_app/features/sessions/services/livekit_service.dart';
import 'package:totem_app/features/sessions/widgets/action_bar.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/emoji_bar.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/shared/totem_icons.dart';

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

  bool _hasPendingChatMessages = false;
  void _onChatMessageReceived(String userIdentity, String message) {
    setState(() => _hasPendingChatMessages = true);
    // TODO(bdlukaa): Show a toast/snackbar with the message
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
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
      body: LivekitRoom(
        roomContext: session.room,
        builder: (context, roomCtx) {
          final room = roomCtx.room;
          final user = room.localParticipant;

          switch (room.connectionState) {
            case ConnectionState.connecting:
            case ConnectionState.reconnecting:
              return const LoadingRoomScreen();
            case ConnectionState.disconnected:
              // TODO(bdlukaa): Disconnected from the room
              return Center(
                child: Text(
                  'Disconnected from the room',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                    color: Colors.white,
                  ),
                ),
              );
            case ConnectionState.connected:
              return RoomBackground(
                child: SafeArea(
                  top: false,
                  child: Column(
                    spacing: 20,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              color: AppTheme.blue,
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Builder(
                                    builder: (context) {
                                      final track =
                                          roomCtx.localVideoTrack ??
                                          user?.videoTrackPublications
                                              .firstWhereOrNull(
                                                (pub) => pub.track != null,
                                              )
                                              ?.track;

                                      if (track != null && track.isActive) {
                                        return VideoTrackRenderer(
                                          track,
                                          fit: VideoViewFit.cover,
                                        );
                                      } else {
                                        return Container(
                                          decoration: BoxDecoration(
                                            image:
                                                auth.user?.profileImage != null
                                                ? DecorationImage(
                                                    image: NetworkImage(
                                                      auth.user!.profileImage!,
                                                    ),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                                PositionedDirectional(
                                  end: 20,
                                  bottom: 20,
                                  child: Text(
                                    user?.identity ?? 'Me',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        const Shadow(blurRadius: 4),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Flexible(
                        child: ParticipantLoop(
                          layoutBuilder:
                              const SessionParticipantsLayoutBuilder(),
                          participantTrackBuilder: (context, identifier) {
                            return ParticipantCard(
                              key: getParticipantKey(
                                identifier.participant.identity,
                              ),
                              participant: identifier.participant,
                              child: Builder(
                                builder: (context) {
                                  final videoTrack = identifier
                                      .participant
                                      .trackPublications
                                      .values
                                      .where(
                                        (t) =>
                                            t.track != null &&
                                            t.kind == TrackType.VIDEO &&
                                            t.track!.isActive,
                                      );
                                  if (videoTrack.isNotEmpty) {
                                    return VideoTrackRenderer(
                                      videoTrack.first.track! as VideoTrack,
                                      fit: VideoViewFit.cover,
                                    );
                                  } else {
                                    return Container(
                                      decoration: BoxDecoration(
                                        image: auth.user?.profileImage != null
                                            ? DecorationImage(
                                                image: NetworkImage(
                                                  auth.user!.profileImage!,
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      // TODO(bdlukaa): Transcriptions
                      ActionBar(
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
                            onPressed: () {
                              setState(() => _hasPendingChatMessages = false);
                              showSessionChatSheet(
                                context,
                                roomCtx,
                                widget.event,
                              );
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const TotemIcon(TotemIcons.chat),
                                if (_hasPendingChatMessages)
                                  Container(
                                    height: 4,
                                    width: 4,
                                    decoration: BoxDecoration(
                                      color: AppTheme.pink,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
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
                              onPressed: () {},
                              icon: const TotemIcon(
                                TotemIcons.more,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
          }
        },
      ),
    );
  }
}
