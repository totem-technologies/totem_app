import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart'
    hide RoomConnectionState;
import 'package:totem_app/api/models/event_detail_schema.dart';
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
  });

  final String token;
  final bool cameraEnabled;
  final bool micEnabled;
  final String eventSlug;
}

class VideoRoomScreen extends ConsumerStatefulWidget {
  const VideoRoomScreen({
    required this.token,
    required this.cameraEnabled,
    required this.micEnabled,
    required this.eventSlug,
    super.key,
  });

  final String token;
  final bool cameraEnabled;
  final bool micEnabled;
  final String eventSlug;

  @override
  ConsumerState<VideoRoomScreen> createState() => _VideoRoomScreenState();
}

class _VideoRoomScreenState extends ConsumerState<VideoRoomScreen> {
  Map<String, GlobalKey> participantKeys = {};
  GlobalKey getParticipantKey(String identity) {
    return participantKeys.putIfAbsent(identity, GlobalKey.new);
  }

  var _showEmojiPicker = false;
  Future<void> _onEmojiReceived(String userIdentity, String emoji) async {
    final userKey = participantKeys[userIdentity];
    if (userKey != null && userKey.currentContext != null) {
      await displayReaction(
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

  Future<void> _onAcceptTotem(LiveKitService sessionNotifier) async {
    await sessionNotifier.acceptTotem();
    if (mounted) {
      setState(() => _receivingTotem = false);
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
          onEmojiReceived: _onEmojiReceived,
          onMessageReceived: _onChatMessageReceived,
          onLivekitError: _onLivekitError,
          onReceiveTotem: _onReceiveTotem,
        );

        final sessionState = ref.watch(liveKitServiceProvider(sessionOptions));
        final sessionNotifier = ref.read(
          liveKitServiceProvider(sessionOptions).notifier,
        );

        return RoomBackground(
          child: LivekitRoom(
            roomContext: sessionNotifier.room,
            builder: (context, roomCtx) {
              return Navigator(
                onDidRemovePage: (page) => {},
                pages: [
                  MaterialPage(
                    child: PopScope(
                      canPop: false,
                      onPopInvokedWithResult: (didPop, result) async {
                        if (didPop) return;
                        final shouldPop =
                            await showLeaveDialog(context) ?? false;
                        if (context.mounted && shouldPop) {
                          popOrHome(context);
                        }
                      },
                      child: _buildBody(event, sessionNotifier, sessionState),
                    ),
                  ),
                ],
              );
            },
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
          if (_receivingTotem) {
            return ReceiveTotemScreen(
              actionBar: buildActionBar(notifier, state, event),
              onAcceptTotem: () => _onAcceptTotem(notifier),
            );
          }

          return MyTurn(
            actionBar: buildActionBar(notifier, state, event),
            getParticipantKey: getParticipantKey,
            onPassTotem: notifier.passTotem,
            event: event,
          );
        } else {
          return NotMyTurn(
            actionBar: buildActionBar(notifier, state, event),
            getParticipantKey: getParticipantKey,
            sessionState: state.sessionState,
            event: event,
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
            Semantics(
              label: room.microphoneOpened
                  ? 'Microphone on. Tap to mute'
                  : 'Microphone off. Tap to unmute',
              child: ActionBarButton(
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
            ),
            Semantics(
              label: room.cameraOpened
                  ? 'Camera on. Tap to turn off'
                  : 'Camera off. Tap to turn on',
              child: ActionBarButton(
                active: room.cameraOpened,
                onPressed: () async {
                  if (room.cameraOpened) {
                    await notifier.disableCamera();
                  } else {
                    await notifier.enableCamera();
                  }
                },
                child: TotemIcon(
                  room.cameraOpened
                      ? TotemIcons.cameraOn
                      : TotemIcons.cameraOff,
                ),
              ),
            ),
            if (!state.isMyTurn(notifier.room))
              Builder(
                builder: (button) {
                  return Semantics(
                    label: 'Send reaction emoji',
                    child: ActionBarButton(
                      active: _showEmojiPicker,
                      onPressed: () async {
                        setState(() => _showEmojiPicker = true);
                        final emoji = await showEmojiBar(button, context);
                        if (emoji != null && emoji.isNotEmpty) {
                          unawaited(notifier.sendEmoji(emoji));
                          if (user?.identity != null) {
                            unawaited(_onEmojiReceived(user!.identity, emoji));
                          }
                        }
                        if (mounted) {
                          setState(() => _showEmojiPicker = false);
                        }
                      },
                      child: const TotemIcon(TotemIcons.reaction),
                    ),
                  );
                },
              ),
            Semantics(
              label: _hasPendingChatMessages
                  ? 'Open chat. New messages available'
                  : 'Open chat',
              child: ActionBarButton(
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
                      Semantics(
                        label: 'New message indicator',
                        child: Container(
                          height: 4,
                          width: 4,
                          decoration: const BoxDecoration(
                            color: AppTheme.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 40,
                maxHeight: 40,
              ),
              child: Semantics(
                label: 'More options',
                button: true,
                child: IconButton(
                  padding: EdgeInsetsDirectional.zero,
                  onPressed: () =>
                      showOptionsSheet(context, state, notifier, event),
                  tooltip: 'More options',
                  icon: const TotemIcon(
                    TotemIcons.more,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
