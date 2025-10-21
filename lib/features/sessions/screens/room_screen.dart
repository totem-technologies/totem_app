import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart'
    hide RoomConnectionState;
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/models/session_state.dart';
import 'package:totem_app/features/sessions/screens/chat_sheet.dart';
import 'package:totem_app/features/sessions/screens/error_screen.dart';
import 'package:totem_app/features/sessions/screens/loading_screen.dart';
import 'package:totem_app/features/sessions/screens/my_turn.dart';
import 'package:totem_app/features/sessions/screens/not_my_turn.dart';
import 'package:totem_app/features/sessions/screens/options_sheet.dart';
import 'package:totem_app/features/sessions/screens/receive_totem_screen.dart';
import 'package:totem_app/features/sessions/screens/session_ended.dart';
import 'package:totem_app/features/sessions/services/livekit_service.dart';
import 'package:totem_app/features/sessions/widgets/action_bar.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/emoji_bar.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/popups.dart';

class VideoRoomScreenRouteArgs {
  const VideoRoomScreenRouteArgs({
    required this.token,
    required this.cameraEnabled,
    required this.micEnabled,
    required this.event,
  });

  final String token;
  final bool cameraEnabled;
  final bool micEnabled;
  final EventDetailSchema event;
}

class VideoRoomScreen extends ConsumerStatefulWidget {
  const VideoRoomScreen({
    required this.token,
    required this.cameraEnabled,
    required this.micEnabled,
    required this.event,
    super.key,
  });

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

  void _onLivekitError(LiveKitException error) {
    if (error is ConnectException ||
        error is MediaConnectException ||
        error is UnexpectedStateException ||
        error is NegotiationError ||
        error is TrackCreateException ||
        error is TrackPublishException) {
      // These errors are shown in the error screen
    } else {
      showErrorPopup(
        context,
        icon: TotemIcons.errorOutlined,
        title: 'Something went wrong',
        message: 'Check your connection and try again.',
      );
    }
  }

  bool _receivingTotem = false;
  void _onReceiveTotem() {
    if (mounted) {
      setState(() => _receivingTotem = true);
    }
  }

  void _onAcceptTotem() {
    if (mounted) {
      setState(() => _receivingTotem = false);
    }
    // TODO(bdlukaa): Invoke accept totem api
  }

  @override
  Widget build(BuildContext context) {
    final sessionOptions = SessionOptions(
      event: widget.event,
      token: widget.token,
      cameraEnabled: widget.cameraEnabled,
      microphoneEnabled: widget.micEnabled,
      onEmojiReceived: _onEmojiReceived,
      onMessageReceived: _onChatMessageReceived,
      onLivekitError: _onLivekitError,
      onReceiveTotem: _onReceiveTotem,
    );

    final sessionState = ref.watch(liveKitServiceProvider(sessionOptions));
    final sessionNotifier = ref.read(
      liveKitServiceProvider(sessionOptions).notifier,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showLeaveDialog(context) ?? false;
        if (context.mounted && shouldPop) {
          popOrHome(context);
        }
      },
      child: RoomBackground(
        child: LivekitRoom(
          roomContext: sessionNotifier.room,
          builder: (context, roomCtx) {
            return Navigator(
              onDidRemovePage: (page) => {},
              pages: [
                MaterialPage(
                  child: _buildBody(sessionNotifier, sessionState),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(LiveKitService notifier, LiveKitState state) {
    return Builder(
      builder: (context) {
        final roomCtx = notifier.room;
        switch (state.connectionState) {
          case RoomConnectionState.error:
            return RoomErrorScreen(onRetry: roomCtx.connect);
          case RoomConnectionState.connecting:
            return const LoadingRoomScreen();
          case RoomConnectionState.disconnected:
            return SessionEndedScreen(event: widget.event);
          case RoomConnectionState.connected:
            if (state.sessionState.status == SessionStatus.ended) {
              return SessionEndedScreen(event: widget.event);
            }
            if (roomCtx.localParticipant == null) {
              return const LoadingRoomScreen();
            }

            if (state.isMyTurn(notifier.room)) {
              if (_receivingTotem) {
                return ReceiveTotemScreen(
                  actionBar: buildActionBar(notifier, state),
                  onAcceptTotem: _onAcceptTotem,
                );
              }
              return MyTurn(
                actionBar: buildActionBar(notifier, state),
                getParticipantKey: getParticipantKey,
                onPassTotem: notifier.passTotem,
              );
            } else {
              return NotMyTurn(
                actionBar: buildActionBar(notifier, state),
                getParticipantKey: getParticipantKey,
                sessionState: state.sessionState,
              );
            }
        }
      },
    );
  }

  Widget buildActionBar(
    LiveKitService notifier,
    LiveKitState state,
  ) {
    return Builder(
      builder: (context) {
        final roomCtx = notifier.room;
        final user = roomCtx.localParticipant;
        final auth = ref.read(authControllerProvider);
        final isKeeper = widget.event.space.author.slug == auth.user?.slug;
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
            if (!state.isMyTurn(notifier.room))
              Builder(
                builder: (button) {
                  return ActionBarButton(
                    active: _showEmojiPicker,
                    onPressed: () async {
                      setState(() => _showEmojiPicker = true);
                      final emoji = await showEmojiBar(button, context);
                      if (emoji != null && emoji.isNotEmpty) {
                        notifier.sendEmoji(emoji);
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
                padding: EdgeInsetsDirectional.zero,
                onPressed: () => showOptionsSheet(
                  context,
                  isKeeper ? notifier.startSession : null,
                ),
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
