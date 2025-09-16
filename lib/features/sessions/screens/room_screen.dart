import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/screens/chat_sheet.dart';
import 'package:totem_app/features/sessions/services/session_controller.dart';
import 'package:totem_app/features/sessions/widgets/action_bar.dart';
import 'package:totem_app/features/sessions/widgets/emoji_bar.dart';
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
  late RoomContext roomContext = RoomContext(
    // room: sessionState.room,
    url: 'wss://totem-d7esbgcp.livekit.cloud',
    token: widget.token,
    connect: true,
    onConnected: _onConnected,
  );

  void _onConnected() {
    // Set initial camera and mic states
    roomContext.localParticipant?.setCameraEnabled(widget.cameraEnabled);
    roomContext.localParticipant?.setMicrophoneEnabled(widget.micEnabled);
  }

  var _showEmojiPicker = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final sessionState = ref.watch(sessionControllerProvider);
    final sessionController = ref.read(sessionControllerProvider.notifier);

    // Join the session when the widget is built
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (sessionState.status == SessionStatus.disconnected) {
    //     sessionController.joinSession(
    //       roomName,
    //       token,
    //       cameraEnabled: cameraEnabled,
    //       micEnabled: micEnabled,
    //     );
    //   }
    // });

    // switch (sessionState.status) {
    //   case SessionStatus.connecting:
    //     return const Scaffold(
    //       body: Center(child: CircularProgressIndicator()),
    //     );
    //   case SessionStatus.error:
    //     return Scaffold(
    //       body: Center(
    //         child: Column(
    //           mainAxisAlignment: MainAxisAlignment.center,
    //           children: [
    //             Text(sessionState.error ?? 'An unknown error occurred.'),
    //             const SizedBox(height: 20),
    //             const Text('Please try again later.'),
    //             ElevatedButton(
    //               onPressed: () {
    //                 sessionController.leaveSession();
    //                 Navigator.of(context).pop();
    //               },
    //               child: const Text('Go Back'),
    //             ),
    //             ElevatedButton(
    //               onPressed: () {
    //                 sessionController
    //                   ..leaveSession()
    //                   ..joinSession(
    //                     roomName,
    //                     token,
    //                     cameraEnabled: cameraEnabled,
    //                     micEnabled: micEnabled,
    //                   );
    //               },
    //               child: const Text('Try again'),
    //             ),
    //           ],
    //         ),
    //       ),
    //     );
    //   case SessionStatus.disconnected:
    //     return const Scaffold(
    //       body: Center(child: Text('Disconnected')),
    //     );
    //   case SessionStatus.connected:
    //     break; // Proceed to render the room
    // }

    return Scaffold(
      body: LivekitRoom(
        roomContext: roomContext,
        builder: (context, roomCtx) {
          final room = roomCtx.room;
          final user = room.localParticipant;

          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.scaffoldBackgroundColor,
                  AppTheme.mauve,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.5, 1],
              ),
            ),
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
                      showAudioTracks: true,

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
                                            child: const VideoTrackWidget(),
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
                            onPressed: () {
                              showEmojiBar(context);
                            },
                            child: const TotemIcon(TotemIcons.reaction),
                          );
                        },
                      ),
                      ActionBarButton(
                        onPressed: () {
                          showSessionChatSheet(context, roomCtx, widget.event);
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
                    /// show chat widget on mobile
                    if (roomCtx.isChatEnabled)
                      Expanded(
                        child: ChatBuilder(
                          builder: (context, enabled, chatCtx, messages) {
                            return ChatWidget(
                              messages: messages,
                              onSend: (message) => chatCtx.sendMessage(message),
                              onClose: () {
                                chatCtx.toggleChat(false);
                              },
                            );
                          },
                        ),
                      )
                    else
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

                            /// show control bar at the bottom
                            const Positioned(
                              bottom: 30,
                              left: 0,
                              right: 0,
                              child: ControlBar(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                /// show toast widget
                const Positioned(
                  top: 30,
                  left: 0,
                  right: 0,
                  child: ToastWidget(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void showEmojiBar(BuildContext button) async {
    setState(() {
      _showEmojiPicker = true;
    });

    final box = button.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
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

    if (response != null) {
      // TODO(bdlukaa): Handle user in messaging
    }

    setState(() {
      _showEmojiPicker = false;
    });
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
