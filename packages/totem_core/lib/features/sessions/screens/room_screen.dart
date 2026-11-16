import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart'
    hide Session, SessionOptions;
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/services/connectivity_service.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/presentation/session_presentation_effects.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/error_screen.dart';
import 'package:totem_core/features/sessions/screens/listening_turn_screen.dart';
import 'package:totem_core/features/sessions/screens/receive_totem_screen.dart';
import 'package:totem_core/features/sessions/screens/session_disconnected.dart';
import 'package:totem_core/features/sessions/screens/speaking_turn_screen.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/features/sessions/widgets/emoji_bar.dart';
import 'package:totem_core/features/sessions/widgets/session_entry_notice.dart';
import 'package:totem_core/features/sessions/widgets/session_panels.dart';

class VideoSessionScreen extends ConsumerStatefulWidget {
  const VideoSessionScreen({
    required this.sessionSlug,
    required this.loadingScreen,
    this.showAdmissionOrientation = false,
    this.admissionReady = false,
    this.isReturningParticipant = false,
    this.sessionStartedAtAdmission,
    this.now = DateTime.now,
    super.key,
  });

  final String sessionSlug;
  final Widget loadingScreen;
  final bool showAdmissionOrientation;
  final bool admissionReady;
  final bool isReturningParticipant;
  final bool? sessionStartedAtAdmission;
  final ValueGetter<DateTime> now;

  @override
  ConsumerState<VideoSessionScreen> createState() => _VideoSessionScreenState();
}

// Use shared helper to determine transient join disconnect reasons.

class _VideoSessionScreenState extends ConsumerState<VideoSessionScreen> {
  static var _didWarmEmojiGlyphs = false;

  bool _admissionOrientationDismissed = false;
  bool? _admissionOrientationEligible;

  @override
  void initState() {
    super.initState();

    _warmEmojiGlyphs();
    ref
      ..listenManual(
        currentSessionProvider,
        (_, _) => _syncAdmissionOrientation(),
      )
      ..listenManual(
        currentSessionEventProvider,
        (_, _) => _syncAdmissionOrientation(),
      )
      ..listenManual(
        resolveCurrentScreenProvider,
        (_, _) => _syncAdmissionOrientation(),
      )
      ..listenManual(
        connectionStateProvider,
        (_, _) => _syncAdmissionOrientation(),
      )
      ..listenManual(roomStatusProvider, (_, _) => _syncAdmissionOrientation());
    _syncAdmissionOrientation(rebuild: false);
  }

  @override
  void didUpdateWidget(covariant VideoSessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAdmissionOrientation(rebuild: false);
  }

  void _syncAdmissionOrientation({bool rebuild = true}) {
    final connection = ref.read(connectionStateProvider);
    final status = ref.read(roomStatusProvider);
    final screen = ref.read(resolveCurrentScreenProvider);
    final event = ref.read(currentSessionEventProvider);
    var eligible = _admissionOrientationEligible;
    var dismissed = _admissionOrientationDismissed;

    if (eligible != null && connection != RoomConnectionState.connected) {
      dismissed = true;
    }
    final waitingForAdmission =
        widget.showAdmissionOrientation && !widget.admissionReady;
    if (eligible == null &&
        !waitingForAdmission &&
        connection == RoomConnectionState.connected &&
        ref.read(currentSessionProvider) != null &&
        event != null &&
        !event.ended &&
        status != RoomStatus.ended &&
        screen != null &&
        screen != RoomScreen.disconnected &&
        screen != RoomScreen.error) {
      // Keeper entry-time status survives delayed rendering and tab suspension.
      // Legacy approvals fall back to the first connected room status.
      eligible =
          widget.showAdmissionOrientation &&
          !widget.isReturningParticipant &&
          (widget.sessionStartedAtAdmission ?? status == RoomStatus.active);
    }
    if (eligible == _admissionOrientationEligible &&
        dismissed == _admissionOrientationDismissed) {
      return;
    }

    void update() {
      _admissionOrientationEligible = eligible;
      _admissionOrientationDismissed = dismissed;
    }

    if (rebuild) {
      setState(update);
    } else {
      update();
    }
  }

  Widget _buildAdmissionOrientation(String? prompt, {required bool desktop}) {
    final size = MediaQuery.sizeOf(context);
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 420,
        maxHeight: size.height * (desktop ? 0.65 : 0.4),
      ),
      child: Padding(
        padding: EdgeInsets.all(desktop ? 24 : 16),
        child: SessionOrientationNotice(
          prompt: prompt,
          onDone: () => setState(() => _admissionOrientationDismissed = true),
        ),
      ),
    );

    if (desktop) {
      return Positioned.fill(
        child: Stack(
          children: [
            const ModalBarrier(dismissible: false, color: Colors.black54),
            Center(child: Dialog(child: content)),
          ],
        ),
      );
    }
    return Positioned(
      left: 16,
      right: 16,
      top: 8,
      child: SafeArea(
        bottom: false,
        child: Center(child: Card(elevation: 8, child: content)),
      ),
    );
  }

  void _warmEmojiGlyphs() {
    if (!kIsWeb) return;
    if (_didWarmEmojiGlyphs) return;
    _didWarmEmojiGlyphs = true;

    // On web, first-time emoji painting may show placeholders briefly while
    // glyphs are being resolved. Painting once off-screen warms the cache.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final textDirection =
          Directionality.maybeOf(context) ?? TextDirection.ltr;
      const style = TextStyle(
        fontSize: 24,
        textBaseline: TextBaseline.ideographic,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      var dy = 0.0;

      for (final emoji in EmojiBar.defaultEmojis) {
        final painter =
            TextPainter(
                text: TextSpan(text: emoji, style: style),
                textDirection: textDirection,
                maxLines: 1,
              )
              ..layout()
              ..paint(canvas, Offset(0, dy));
        dy += painter.height + 2;
        painter.dispose();
      }

      recorder.endRecording().dispose();
    });
  }

  @override
  Widget build(BuildContext context) => SessionPresentationEffects(
    now: widget.now,
    child: _buildSession(context),
  );

  Widget _buildSession(BuildContext context) {
    final currentSession = ref.watch(currentSessionProvider);
    final currentRoomScreen = ref.watch(resolveCurrentScreenProvider);
    final currentSessionEvent = ref.watch(currentSessionEventProvider);

    if (currentSession == null ||
        currentRoomScreen == null ||
        currentSessionEvent == null) {
      return SessionPanels(
        sessionSlug: widget.sessionSlug,
        child: widget.loadingScreen,
      );
    }

    final connectionState = ref.watch(connectionStateProvider);
    final roomStatus = ref.watch(roomStatusProvider);
    final disconnectReason = ref.watch(disconnectionReasonProvider);

    // Early transient join recovery check: keep showing the loading screen
    // when a join attempt failed transiently (e.g. signaling hiccup). This
    // must be evaluated before honoring a room-ended state so the UI
    // doesn't prematurely show the disconnected screen while the client
    // is still attempting to recover a join.
    final isTransientJoinRecoveryEarly =
        currentRoomScreen == RoomScreen.loading &&
        connectionState == RoomConnectionState.disconnected &&
        isTransientJoinDisconnectReason(disconnectReason);

    if (isTransientJoinRecoveryEarly) {
      return SessionPanels(
        sessionSlug: widget.sessionSlug,
        child: widget.loadingScreen,
      );
    }

    final showingDisconnectedScreen =
        currentSessionEvent.ended ||
        roomStatus == RoomStatus.ended ||
        currentRoomScreen == RoomScreen.disconnected ||
        currentRoomScreen == RoomScreen.error;
    final isOffline = ref.watch(isOfflineProvider).value ?? false;

    if (currentSessionEvent.ended || roomStatus == RoomStatus.ended) {
      return SessionPanels(
        sessionSlug: widget.sessionSlug,
        child: RoomBackground(
          status: RoomStatus.ended,
          child: SessionDisconnectedScreen(
            session: currentSessionEvent,
            disconnectReason: disconnectReason,
          ),
        ),
      );
    }

    // The Keeper-approved, fully activated local connection can enter without
    // waiting for a separate roster packet. The roster still filters everyone
    // shown to other participants.
    final waitingForAdmission =
        widget.showAdmissionOrientation && !widget.admissionReady;
    final admissionEstablished =
        !waitingForAdmission &&
        connectionState == RoomConnectionState.connected &&
        !showingDisconnectedScreen;
    final readyForOrientation =
        admissionEstablished && currentRoomScreen != RoomScreen.loading;

    final showOrientation =
        readyForOrientation &&
        roomStatus == RoomStatus.active &&
        _admissionOrientationEligible == true &&
        !_admissionOrientationDismissed;
    final admissionPrompt = showOrientation
        ? ref.watch(currentSessionPromptProvider)
        : null;

    return SessionPanels(
      sessionSlug: widget.sessionSlug,
      session: currentSession,
      connectionState: connectionState,
      roomStatus: roomStatus,
      enableEmojiReactions:
          !waitingForAdmission && currentRoomScreen == RoomScreen.listening,
      orientationBuilder: showOrientation
          ? (context, docked) =>
                _buildAdmissionOrientation(admissionPrompt, desktop: docked)
          : null,
      child: _buildBody(
        currentSession,
        waitingForAdmission ? RoomScreen.loading : currentRoomScreen,
        currentSessionEvent,
        disconnectReason,
        isOffline: isOffline,
      ),
    );
  }

  Widget _buildBody(
    SessionController session,
    RoomScreen screen,
    SessionDetailSchema sessionEvent,
    DisconnectReason? disconnectReason, {
    required bool isOffline,
  }) {
    final isInternetDisconnect =
        isInternetDisconnectReason(disconnectReason) ||
        (isOffline &&
            canOfflineStateOverrideDisconnectReason(disconnectReason));
    final disconnectionError = disconnectReason == null
        ? null
        : RoomDisconnectionError(disconnectReason);

    switch (screen) {
      case RoomScreen.error:
        return SessionErrorScreen(
          onRetry: session.join,
          error: disconnectionError,
        );
      case RoomScreen.loading:
        return widget.loadingScreen;
      case RoomScreen.disconnected:
        if (isInternetDisconnect) {
          return SessionErrorScreen(
            onRetry: session.join,
            error: disconnectionError,
          );
        }
        return SessionDisconnectedScreen(
          session: sessionEvent,
          disconnectReason: disconnectReason,
        );
      case RoomScreen.receiving:
        return const ReceiveTotemScreen();
      case RoomScreen.speaking:
      case RoomScreen.passing:
        return SpeakingTurnScreen(session: session.session!);
      case RoomScreen.listening:
        return ListeningTurnScreen(session: session.session!);
    }
  }
}
