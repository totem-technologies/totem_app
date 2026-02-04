import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart'
    hide Session, SessionOptions;
import 'package:livekit_components/livekit_components.dart'
    hide RoomConnectionState;
import 'package:totem_app/api/export.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_app/features/sessions/screens/chat_sheet.dart';
import 'package:totem_app/features/sessions/screens/error_screen.dart';
import 'package:totem_app/features/sessions/screens/my_turn.dart';
import 'package:totem_app/features/sessions/screens/not_my_turn.dart';
import 'package:totem_app/features/sessions/screens/options_sheet.dart';
import 'package:totem_app/features/sessions/screens/receive_totem_screen.dart';
import 'package:totem_app/features/sessions/screens/session_ended.dart';
import 'package:totem_app/features/sessions/services/session_service.dart';
import 'package:totem_app/features/sessions/widgets/action_bar.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/emoji_bar.dart';
import 'package:totem_app/features/sessions/widgets/protection_overlay.dart';
import 'package:totem_app/features/sessions/widgets/speaking_indicator.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/popups.dart';

class VideoRoomScreen extends ConsumerStatefulWidget {
  const VideoRoomScreen({
    required this.eventSlug,
    required this.sessionOptions,
    required this.event,
    required this.loadingScreen,
    required this.actionBarKey,
    super.key,
  });

  final String eventSlug;
  final SessionOptions sessionOptions;
  final SessionDetailSchema event;
  final Widget loadingScreen;
  final GlobalKey actionBarKey;

  @override
  ConsumerState<VideoRoomScreen> createState() => _VideoRoomScreenState();
}

class _VideoRoomScreenState extends ConsumerState<VideoRoomScreen> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  SessionOptions? _cachedSessionOptions;

  @override
  void initState() {
    super.initState();
    _buildSessionOptions();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _listenToBatteryChanges();
  }

  @override
  void didUpdateWidget(covariant VideoRoomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _buildSessionOptions();
  }

  SessionOptions _buildSessionOptions() {
    return _cachedSessionOptions = SessionOptions(
      eventSlug: widget.sessionOptions.eventSlug,
      token: widget.sessionOptions.token,
      cameraEnabled: widget.sessionOptions.cameraEnabled,
      microphoneEnabled: widget.sessionOptions.microphoneEnabled,
      cameraOptions: widget.sessionOptions.cameraOptions,
      audioOptions: widget.sessionOptions.audioOptions,
      audioOutputOptions: widget.sessionOptions.audioOutputOptions,
      onConnected: widget.sessionOptions.onConnected,
      onEmojiReceived: _onEmojiReceived,
      onMessageReceived: _onChatMessageReceived,
      onLivekitError: _onLivekitError,
      onKeeperLeaveRoom: _onKeeperLeft,
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _batterySubscription?.cancel();
    super.dispose();
  }

  final battery = Battery();
  bool _shouldShowLowBatteryWarning = false;
  StreamSubscription<BatteryState>? _batterySubscription;
  void _listenToBatteryChanges() {
    try {
      _batterySubscription = battery.onBatteryStateChanged.listen((
        state,
      ) async {
        if (!mounted) return;
        if (state == BatteryState.charging && _shouldShowLowBatteryWarning) {
          setState(() => _shouldShowLowBatteryWarning = false);
        } else if (state == BatteryState.discharging) {
          try {
            final level = await battery.batteryLevel;
            if (level <= 20 && !_shouldShowLowBatteryWarning) {
              _shouldShowLowBatteryWarning = true;
              if (mounted) {
                setState(() {});
                showNotificationPopup(
                  context,
                  icon: TotemIcons.person,
                  title: 'Your battery is running low',
                  message: 'You might want to plug in.',
                );
              }
            }
          } catch (_) {
            // Unable to get battery level
          }
        }
      });
    } catch (_) {
      // Battery monitoring not available
    }
  }

  Map<String, GlobalKey> participantKeys = {};
  GlobalKey getParticipantKey(String identity) {
    return participantKeys.putIfAbsent(identity, GlobalKey.new);
  }

  var _showEmojiPicker = false;
  void _onEmojiReceived(String userIdentity, String emoji) {
    if (!mounted) return;
    ref
        .read(emojiReactionsProvider.notifier)
        .addReaction(context, userIdentity, emoji);
  }

  bool _chatSheetOpen = false;
  bool _hasPendingChatMessages = false;
  void _onChatMessageReceived(String userIdentity, String message) {
    if (!mounted || _chatSheetOpen) return;
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

  VoidCallback _onKeeperLeft(Session room) {
    return showPermanentNotificationPopup(
      context,
      icon: TotemIcons.community,
      title: 'The session has been paused.',
      message: 'The keeper will be right back.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(
      sessionProvider(_cachedSessionOptions ?? _buildSessionOptions()),
    );
    final session = ref.read(
      sessionProvider(_cachedSessionOptions ?? _buildSessionOptions()).notifier,
    );

    if (widget.event.ended ||
        (session.event?.ended ?? false) ||
        sessionState.sessionState.status == SessionStatus.ended) {
      return RoomBackground(
        status: sessionState.sessionState.status,
        child: SessionEndedScreen(event: widget.event, session: session),
      );
    }

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
        if (sessionState.connectionState != RoomConnectionState.connecting &&
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
        status: sessionState.sessionState.status,
        child: LivekitRoom(
          roomContext: session.context!,
          builder: (context, _) {
            // Use a navigator for modal sheets and dialogs inside the room
            return Navigator(
              key: _navigatorKey,
              clipBehavior: Clip.none,
              onDidRemovePage: (page) => {},
              pages: [
                MaterialPage(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: _buildBody(session, sessionState),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Overlay(key: EmojiReactions.emojiOverlayKey),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(Session session, SessionRoomState state) {
    switch (state.connectionState) {
      case RoomConnectionState.error:
        return RoomErrorScreen(onRetry: session.context?.connect);
      case RoomConnectionState.connecting:
        return widget.loadingScreen;
      case RoomConnectionState.disconnected:
        return SessionEndedScreen(event: widget.event, session: session);
      case RoomConnectionState.connected:
        if (state.sessionState.status == SessionStatus.ended) {
          return SessionEndedScreen(event: widget.event, session: session);
        }

        if (session.context?.localParticipant == null) {
          return widget.loadingScreen;
        }

        if (state.sessionState.totemStatus == TotemStatus.passing &&
            state.amNext(session.context!)) {
          return ReceiveTotemScreen(
            session: session,
            sessionState: state,
            actionBar: buildActionBar(session, state, widget.event),
            onAcceptTotem: session.acceptTotem,
          );
        }

        if (state.isMyTurn(session.context!)) {
          return ProtectionOverlay(
            child: MyTurn(
              actionBar: buildActionBar(session, state, widget.event),
              getParticipantKey: getParticipantKey,
              onPassTotem: () async {
                try {
                  await session.passTotem();
                  return true;
                } catch (error) {
                  if (!mounted) return false;
                  ErrorHandler.handleApiError(context, error);
                  return false;
                }
              },
              session: session,
              sessionState: state,
              event: widget.event,
            ),
          );
        } else {
          return ProtectionOverlay(
            child: NotMyTurn(
              actionBar: buildActionBar(session, state, widget.event),
              getParticipantKey: getParticipantKey,
              sessionState: state,
              session: session,
              event: widget.event,
            ),
          );
        }
    }
  }

  Widget buildActionBar(
    Session session,
    SessionRoomState state,
    SessionDetailSchema event,
  ) {
    return Builder(
      builder: (context) {
        final room = session.context!;
        final user = room.localParticipant!;

        final isUserTileVisible =
            getParticipantKey(user.identity).currentContext != null;

        return ActionBar(
          key: widget.actionBarKey,
          children: [
            ActionBarButton(
              semanticsLabel:
                  'Microphone ${room.microphoneOpened ? 'on' : 'off'}',
              active: room.microphoneOpened,
              onPressed: () async {
                if (room.microphoneOpened) {
                  await session.disableMicrophone();
                } else {
                  await session.enableMicrophone();
                }
              },
              // if the user tile is not visible, display the speaking indicator
              // when the microphone is opened
              child: !isUserTileVisible && room.microphoneOpened
                  ? SpeakingIndicator(
                      participant: user,
                      foregroundColor: Colors.black,
                      barCount: 5,
                    )
                  : TotemIcon(
                      room.microphoneOpened
                          ? TotemIcons.microphoneOn
                          : TotemIcons.microphoneOff,
                    ),
            ),
            ActionBarButton(
              semanticsLabel: 'Camera ${room.cameraOpened ? 'on' : 'off'}',
              active: room.cameraOpened,
              onPressed: () async {
                if (room.cameraOpened) {
                  await session.disableCamera();
                } else {
                  await session.enableCamera();
                }
              },
              child: TotemIcon(
                room.cameraOpened ? TotemIcons.cameraOn : TotemIcons.cameraOff,
              ),
            ),
            if (!state.isMyTurn(room))
              Builder(
                builder: (button) {
                  return ActionBarButton(
                    semanticsLabel: 'Send reaction',
                    semanticsHint: 'Open emoji selection overlay',
                    active: _showEmojiPicker,
                    onPressed: () async {
                      setState(() => _showEmojiPicker = true);
                      await showEmojiBar(
                        button,
                        onEmojiSelected: (emoji) {
                          session.sendReaction(emoji);
                          _onEmojiReceived(user.identity, emoji);
                        },
                      );
                      if (mounted) setState(() => _showEmojiPicker = false);
                    },
                    child: const TotemIcon(TotemIcons.reaction),
                  );
                },
              ),
            ActionBarButton(
              semanticsLabel: 'Chat',
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
                    showOptionsSheet(context, state, session, event),
                icon: const TotemIcon(
                  TotemIcons.more,
                  color: Colors.white,
                ),
                tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
              ),
            ),
          ],
        );
      },
    );
  }
}
