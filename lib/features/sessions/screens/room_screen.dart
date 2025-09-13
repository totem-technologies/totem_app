import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/services/session_controller.dart';

class VideoRoomScreen extends ConsumerWidget {
  const VideoRoomScreen({
    required this.roomName,
    required this.token,
    super.key,
    this.cameraEnabled = true,
    this.micEnabled = true,
  });

  final String roomName;
  final String token;
  final bool cameraEnabled;
  final bool micEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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

    return LivekitRoom(
      roomContext: RoomContext(
      ),
      builder: (context, roomCtx) {
        return Container(
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
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.blue,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                ),
              ),
              const ControlBar(),
            ],
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
    );
  }
}
