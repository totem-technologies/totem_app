import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' hide SessionOptions;
import 'package:livekit_components/livekit_components.dart'
    hide RoomConnectionState;
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/api/models/totem_status.dart';
import 'package:totem_app/core/config/theme.dart';
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
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/popups.dart';

class VideoRoomScreenRouteArgs {
  const VideoRoomScreenRouteArgs({
    required this.token,
    required this.cameraEnabled,
    required this.micEnabled,
    required this.eventSlug,
    required this.cameraOptions,
    required this.audioOptions,
    required this.audioOutputOptions,
  });

  final String token;
  final bool cameraEnabled;
  final bool micEnabled;
  final String eventSlug;

  final CameraCaptureOptions cameraOptions;
  final AudioCaptureOptions audioOptions;
  final AudioOutputOptions audioOutputOptions;
}

class VideoRoomScreen extends ConsumerStatefulWidget {
  const VideoRoomScreen({
    required this.token,
    required this.cameraEnabled,
    required this.micEnabled,
    required this.eventSlug,
    required this.cameraOptions,
    required this.audioOptions,
    required this.audioOutputOptions,
    super.key,
  });

  final String token;
  final bool cameraEnabled;
  final bool micEnabled;
  final String eventSlug;

  final CameraCaptureOptions cameraOptions;
  final AudioCaptureOptions audioOptions;
  final AudioOutputOptions audioOutputOptions;

  @override
  ConsumerState<VideoRoomScreen> createState() => _VideoRoomScreenState();
}

class _VideoRoomScreenState extends ConsumerState<VideoRoomScreen> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  @override
  void dispose() {
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
    );
    super.dispose();
  }

  Map<String, GlobalKey> participantKeys = {};
  GlobalKey getParticipantKey(String identity) {
    return participantKeys.putIfAbsent(identity, GlobalKey.new);
  }

  var _showEmojiPicker = false;
  final _reactions = <MapEntry<String, String>>[];
  Future<void> _onEmojiReceived(String userIdentity, String emoji) async {
    if (!mounted) return;
    final entry = MapEntry(userIdentity, emoji);
    setState(() => _reactions.add(entry));
    await displayReaction(context, emoji);
    _reactions.remove(entry);
    if (mounted) setState(() {});
  }

  bool _chatSheetOpen = false;
  bool _hasPendingChatMessages = false;
  void _onChatMessageReceived(String userIdentity, String message) {
    if (!mounted) return;
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
      if (mounted) {
        showErrorPopup(
          context,
          icon: TotemIcons.errorOutlined,
          title: 'Something went wrong',
          message: 'Check your connection and try again.',
        );
      }
    }
  }

  Future<void> _onAcceptTotem(LiveKitService sessionNotifier) async {
    try {
      await sessionNotifier.acceptTotem();
    } catch (error) {
      if (mounted) {
        showErrorPopup(
          context,
          icon: TotemIcons.errorOutlined,
          title: 'Something went wrong',
          message: 'We were unable to accept the totem. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventProvider(widget.eventSlug));

    return eventAsync.when(
      data: (event) {
        final sessionOptions = SessionOptions(
          eventSlug: widget.eventSlug,
          keeperSlug: event.space.author.slug!,
          token: widget.token,
          cameraEnabled: widget.cameraEnabled,
          microphoneEnabled: widget.micEnabled,
          cameraOptions: widget.cameraOptions,
          audioOptions: widget.audioOptions,
          audioOutputOptions: widget.audioOutputOptions,
          onEmojiReceived: _onEmojiReceived,
          onMessageReceived: _onChatMessageReceived,
          onLivekitError: _onLivekitError,
        );

        final sessionState = ref.watch(liveKitServiceProvider(sessionOptions));
        final sessionNotifier = ref.read(
          liveKitServiceProvider(sessionOptions).notifier,
        );

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;

            // Checks if there is any other route above the first route.
            //   This route would be a modal sheet or a dialog.
            final navigator = _navigatorKey.currentState;
            if (navigator?.canPop() ?? false) {
              navigator!.pop();
              return;
            }

            // If there is no other route above the first route, the user is
            // trying to leave the session.

            // If the session is not connected or connecting, leave the session.
            if (sessionState.connectionState !=
                    RoomConnectionState.connecting &&
                sessionState.connectionState != RoomConnectionState.connected) {
              popOrHome(context);
              return;
            }

            // If the session is connected, show a dialog to confirm the action.
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
                  key: _navigatorKey,
                  clipBehavior: Clip.none,
                  onDidRemovePage: (page) => {},
                  pages: [
                    MaterialPage(
                      child: _buildBody(event, sessionNotifier, sessionState),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
      loading: () => const LoadingRoomScreen(),
      error: (error, stackTrace) {
        return RoomErrorScreen(
          onRetry: () => ref.refresh(eventProvider(widget.eventSlug).future),
        );
      },
    );
  }

  Widget _buildBody(
    EventDetailSchema event,
    LiveKitService notifier,
    LiveKitState state,
  ) {
    final roomCtx = notifier.room;
    switch (state.connectionState) {
      case RoomConnectionState.error:
        return RoomErrorScreen(onRetry: roomCtx.connect);
      case RoomConnectionState.connecting:
        return const LoadingRoomScreen();
      case RoomConnectionState.disconnected:
        return SessionEndedScreen(event: event);
      case RoomConnectionState.connected:
        if (state.sessionState.status == SessionStatus.ended) {
          return SessionEndedScreen(event: event);
        }
        if (roomCtx.localParticipant == null) {
          return const LoadingRoomScreen();
        }

        if (state.isMyTurn(notifier.room)) {
          if (state.sessionState.totemStatus == TotemStatus.passing) {
            return ReceiveTotemScreen(
              actionBar: buildActionBar(notifier, state, event),
              onAcceptTotem: () => _onAcceptTotem(notifier),
            );
          }

          return MyTurn(
            actionBar: buildActionBar(notifier, state, event),
            getParticipantKey: getParticipantKey,
            onPassTotem: notifier.passTotem,
            sessionState: state.sessionState,
            event: event,
            emojis: _reactions,
          );
        } else {
          return NotMyTurn(
            actionBar: buildActionBar(notifier, state, event),
            getParticipantKey: getParticipantKey,
            sessionState: state.sessionState,
            session: notifier,
            event: event,
            emojis: _reactions,
          );
        }
    }
  }

  Widget buildActionBar(
    LiveKitService notifier,
    LiveKitState state,
    EventDetailSchema event,
  ) {
    return Builder(
      builder: (context) {
        final room = notifier.room;
        final user = room.localParticipant;
        return ActionBar(
          children: [
            ActionBarButton(
              active: room.microphoneOpened,
              onPressed: () async {
                if (room.microphoneOpened) {
                  await notifier.disableMicrophone();
                } else {
                  await notifier.enableMicrophone();
                }
              },
              child: TotemIcon(
                room.microphoneOpened
                    ? TotemIcons.microphoneOn
                    : TotemIcons.microphoneOff,
              ),
            ),
            ActionBarButton(
              active: room.cameraOpened,
              onPressed: () async {
                if (room.cameraOpened) {
                  await notifier.disableCamera();
                } else {
                  await notifier.enableCamera();
                }
              },
              child: TotemIcon(
                room.cameraOpened ? TotemIcons.cameraOn : TotemIcons.cameraOff,
              ),
            ),
            if (!state.isMyTurn(notifier.room))
              Builder(
                builder: (button) {
                  return ActionBarButton(
                    active: _showEmojiPicker,
                    onPressed: () async {
                      setState(() => _showEmojiPicker = true);
                      await showEmojiBar(
                        button,
                        context,
                        onEmojiSelected: (emoji) {
                          unawaited(notifier.sendEmoji(emoji));
                          if (user?.identity != null) {
                            unawaited(_onEmojiReceived(user!.identity, emoji));
                          }
                        },
                      );
                      if (mounted) setState(() => _showEmojiPicker = false);
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
                await showSessionChatSheet(context, event);
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
                onPressed: () =>
                    showOptionsSheet(context, state, notifier, event),
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
