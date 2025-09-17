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
  var _showEmojiPicker = false;

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
                          ),
                        ),
                      ),
                      Flexible(
                        child: ParticipantLoop(
                          layoutBuilder:
                              const SessionParticipantsLayoutBuilder(),
                          participantTrackBuilder: (context, identifier) {
                            return ParticipantCard(
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
                            // build participant widget for each Track
                            return Padding(
                              padding: const EdgeInsets.all(2),
                              child: Stack(
                                children: [
                                  /// status bar at the bottom
                                  const Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: ParticipantStatusBar(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
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
                            builder: (context) {
                              return ActionBarButton(
                                active: _showEmojiPicker,
                                onPressed: () async {
                                  setState(() {
                                    _showEmojiPicker = true;
                                  });
                                  final emoji = await showEmojiBar(context);
                                  if (emoji != null && emoji.isNotEmpty) {
                                    session.sendEmoji(emoji);
                                  }
                                  setState(() {
                                    _showEmojiPicker = false;
                                  });
                                },
                                child: const TotemIcon(TotemIcons.reaction),
                              );
                            },
                          ),
                          ActionBarButton(
                            onPressed: () {
                              showSessionChatSheet(
                                context,
                                roomCtx,
                                widget.event,
                              );
                            },
                            child: const TotemIcon(TotemIcons.chat),
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
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'LiveKit Components',
                style: TextStyle(color: Colors.white),
              ),
              actions: [
                /// show clear pin button
                if (roomCtx.connected) const ClearPinButton(),
              ],
            ),
            body: Stack(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Stack(
                        children: <Widget>[
                          /* Expanded(
                                        child: TranscriptionBuilder(
                                          builder:
                                              (context, roomCtx, transcriptions) {
                                            return TranscriptionWidget(
                                              transcriptions: transcriptions,
                                            );
                                          },
                                        ),
                                      ),*/
                          /// show participant loop
                          ParticipantLoop(
                            showAudioTracks: true,
                            showVideoTracks: true,
                            showParticipantPlaceholder: true,

                            /// layout builder
                            layoutBuilder: roomCtx.pinnedTracks.isNotEmpty
                                ? const CarouselLayoutBuilder()
                                : const GridLayoutBuilder(),

                            /// participant builder
                            participantTrackBuilder: (context, identifier) {
                              // build participant widget for each Track
                              return Padding(
                                padding: const EdgeInsets.all(2),
                                child: Stack(
                                  children: [
                                    /// video track widget in the background
                                    if (identifier.isAudio &&
                                        roomCtx.enableAudioVisulizer)
                                      const AudioVisualizerWidget(
                                        backgroundColor: LKColors.lkDarkBlue,
                                      )
                                    else
                                      IsSpeakingIndicator(
                                        builder: (context, isSpeaking) {
                                          return isSpeaking != null
                                              ? IsSpeakingIndicatorWidget(
                                                  isSpeaking: isSpeaking,
                                                  child:
                                                      const VideoTrackWidget(),
                                                )
                                              : const VideoTrackWidget();
                                        },
                                      ),

                                    /// focus toggle button at the top right
                                    const Positioned(
                                      top: 0,
                                      right: 0,
                                      child: FocusToggle(),
                                    ),

                                    /// track stats at the top left
                                    const Positioned(
                                      top: 8,
                                      left: 0,
                                      child: TrackStatsWidget(),
                                    ),

                                    /// status bar at the bottom
                                    const Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: ParticipantStatusBar(),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<String?> showEmojiBar(BuildContext button) async {
    final box = button.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return null;
    final position = box.localToGlobal(Offset.zero, ancestor: overlay);

    final response = await Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return Stack(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: Container(
                  color: Colors.transparent,
                ),
              ),
              PositionedDirectional(
                start: 20,
                end: 20,
                top: position.dy - 60,
                child: FadeTransition(
                  opacity: animation,
                  child: EmojiBar(
                    onEmojiSelected: (emoji) {
                      Navigator.of(context).pop(emoji);
                    },
                    emojis: const [
                      '👍',
                      '👏',
                      '😂',
                      '😍',
                      '😮',
                      '😢',
                      '🔥',
                      '💯',
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return response;
  }
}

extension on List<LocalTrackPublication<LocalVideoTrack>> {
  LocalTrackPublication<LocalVideoTrack>? firstWhereOrNull(
    bool Function(LocalTrackPublication<LocalVideoTrack> element) test,
  ) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
