import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/screens/chat_sheet.dart';
import 'package:totem_app/features/sessions/screens/options_sheet.dart';
import 'package:totem_app/features/sessions/widgets/emoji_bar.dart';
import 'package:totem_app/features/sessions/widgets/speaking_indicator.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/popups.dart';

class ActionBarButton extends StatelessWidget {
  const ActionBarButton({
    required this.child,
    required this.onPressed,
    this.semanticsLabel,
    this.square = true,
    this.active = false,
    this.semanticsHint,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool active;
  final bool square;

  final String? semanticsLabel;
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = active ? AppTheme.mauve : AppTheme.white;
    return Semantics(
      button: true,
      label: semanticsLabel,
      hint: semanticsHint,
      enabled: onPressed != null,
      excludeSemantics: semanticsLabel != null,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          decoration: BoxDecoration(
            color: active ? AppTheme.white : AppTheme.mauve,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: foregroundColor),
          ),
          child: Center(
            child: IconTheme.merge(
              data: IconThemeData(
                color: foregroundColor,
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: foregroundColor,
                ),
                child: SizedBox.square(
                  dimension: square ? 24 : null,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ActionBar extends StatelessWidget {
  const ActionBar({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x40000000),
          borderRadius: BorderRadius.circular(30),
        ),
        margin: const EdgeInsetsDirectional.only(bottom: 20),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 20,
            children: [
              for (final child in children) child,
            ],
          ),
        ),
      ),
    );
  }
}

typedef ActionBarButtonToggleCallback =
    Future<void> Function(bool shouldEnable);

class ActionBarMicButton extends StatefulWidget {
  const ActionBarMicButton({
    required this.participant,
    required this.onToggle,
    this.indicatorColor = Colors.black,
    this.indicatorBarCount = 5,
    super.key,
  });

  final LocalParticipant participant;
  final ActionBarButtonToggleCallback onToggle;
  final Color indicatorColor;
  final int indicatorBarCount;

  @override
  State<ActionBarMicButton> createState() => _ActionBarMicButtonState();
}

class _ActionBarMicButtonState extends State<ActionBarMicButton> {
  EventsListener<ParticipantEvent>? _participantListener;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bindListener();
  }

  @override
  void didUpdateWidget(covariant ActionBarMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant.sid != widget.participant.sid) {
      _bindListener();
    }
  }

  void _bindListener() {
    _participantListener?.dispose();
    _participantListener = widget.participant.createListener()
      ..on<ParticipantEvent>((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _participantListener?.dispose();
    super.dispose();
  }

  TrackPublication<Track>? get _audioPublication {
    return widget.participant.getTrackPublicationBySource(
      TrackSource.microphone,
    );
  }

  bool get _isMicrophoneEnabled {
    final publication = _audioPublication;
    if (publication == null) return false;

    final track = publication.track;
    final isMuted = track?.muted ?? publication.muted;
    final isActive = track?.isActive ?? true;
    return isActive && !isMuted;
  }

  Future<void> _toggleMicrophone() async {
    if (_busy) return;

    setState(() => _busy = true);
    try {
      await widget.onToggle(!_isMicrophoneEnabled);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = _isMicrophoneEnabled;

    return ActionBarButton(
      semanticsLabel: 'Microphone ${isEnabled ? 'on' : 'off'}',
      active: isEnabled,
      onPressed: _busy ? null : _toggleMicrophone,
      child: isEnabled
          ? SpeakingIndicator(
              participant: widget.participant,
              foregroundColor: widget.indicatorColor,
              barCount: widget.indicatorBarCount,
            )
          : const TotemIcon(TotemIcons.microphoneOff),
    );
  }
}

class ActionBarCameraButton extends StatefulWidget {
  const ActionBarCameraButton({
    required this.participant,
    required this.onToggle,
    super.key,
  });

  final LocalParticipant participant;
  final ActionBarButtonToggleCallback onToggle;

  @override
  State<ActionBarCameraButton> createState() => _ActionBarCameraButtonState();
}

class _ActionBarCameraButtonState extends State<ActionBarCameraButton> {
  EventsListener<ParticipantEvent>? _participantListener;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bindListener();
  }

  @override
  void didUpdateWidget(covariant ActionBarCameraButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant.sid != widget.participant.sid) {
      _bindListener();
    }
  }

  void _bindListener() {
    _participantListener?.dispose();
    _participantListener = widget.participant.createListener()
      ..on<ParticipantEvent>((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _participantListener?.dispose();
    super.dispose();
  }

  TrackPublication<Track>? get _cameraPublication {
    return widget.participant.getTrackPublicationBySource(TrackSource.camera);
  }

  bool get _isCameraEnabled {
    final publication = _cameraPublication;
    if (publication == null) return false;

    final track = publication.track;
    final isMuted = track?.muted ?? publication.muted;
    final isActive = track?.isActive ?? true;
    return isActive && !isMuted;
  }

  Future<void> _toggleCamera() async {
    if (_busy) return;

    setState(() => _busy = true);
    try {
      await widget.onToggle(!_isCameraEnabled);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = _isCameraEnabled;

    return ActionBarButton(
      semanticsLabel: 'Camera ${isEnabled ? 'on' : 'off'}',
      active: isEnabled,
      onPressed: _busy ? null : _toggleCamera,
      child: TotemIcon(
        isEnabled ? TotemIcons.cameraOn : TotemIcons.cameraOff,
      ),
    );
  }
}

class ActionBarEmojiButton extends StatefulWidget {
  const ActionBarEmojiButton({required this.onEmojiSelected, super.key});

  final ValueChanged<String> onEmojiSelected;

  @override
  State<ActionBarEmojiButton> createState() => _ActionBarEmojiButtonState();
}

class _ActionBarEmojiButtonState extends State<ActionBarEmojiButton> {
  var _isOpen = false;

  Future<void> _openPicker(BuildContext buttonContext) async {
    if (_isOpen) return;

    setState(() => _isOpen = true);
    try {
      await showEmojiBar(
        buttonContext,
        onEmojiSelected: widget.onEmojiSelected,
      );
    } finally {
      if (mounted) setState(() => _isOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) {
        return ActionBarButton(
          semanticsLabel: 'Send reaction',
          semanticsHint: 'Open emoji selection overlay',
          active: _isOpen,
          onPressed: () => _openPicker(buttonContext),
          child: const TotemIcon(TotemIcons.reaction),
        );
      },
    );
  }
}

class SessionActionBar extends ConsumerStatefulWidget {
  const SessionActionBar({super.key});

  @override
  ConsumerState<SessionActionBar> createState() => _SessionActionBarState();

  static final GlobalKey actionBarKey = GlobalKey();
}

class _SessionActionBarState extends ConsumerState<SessionActionBar> {
  bool _chatSheetOpen = false;
  bool _hasPendingSessionChatMessages = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(
      lastSessionMessageProvider,
      (previous, next) {
        if (next == null || identical(previous, next)) return;
        if (!mounted || _chatSheetOpen) return;
        setState(() => _hasPendingSessionChatMessages = !_chatSheetOpen);
        showNotificationPopup(
          context,
          icon: TotemIcons.chat,
          title: 'New message',
          message: next.message,
          // controller: _notificationController,
        );
      },
    );
    final session = ref.watch(currentSessionProvider)!;
    final user = session.room!.localParticipant!;

    final microphoneButton = ActionBarMicButton(
      participant: user,
      indicatorColor: Colors.black,
      indicatorBarCount: 5,
      onToggle: (shouldEnable) async {
        if (shouldEnable) {
          await session.devices.enableMicrophone();
        } else {
          await session.devices.disableMicrophone();
        }
      },
    );

    final cameraButton = ActionBarCameraButton(
      participant: user,
      onToggle: (shouldEnable) async {
        if (shouldEnable) {
          await session.devices.enableCamera();
        } else {
          await session.devices.disableCamera();
        }
      },
    );

    final emojiBarButton = ActionBarEmojiButton(
      onEmojiSelected: (emoji) {
        session.messaging.sendReaction(emoji);
      },
    );

    final chatButton = ActionBarButton(
      semanticsLabel: 'Chat',
      active: _chatSheetOpen,
      onPressed: () async {
        if (!mounted) return;
        setState(() {
          _hasPendingSessionChatMessages = false;
          _chatSheetOpen = true;
        });
        await showSessionChatSheet(context);
        if (!mounted) return;
        setState(() => _chatSheetOpen = false);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const TotemIcon(TotemIcons.chat),
          if (_hasPendingSessionChatMessages)
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
    );

    final moreButton = ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 40,
        maxHeight: 40,
      ),
      child: IconButton(
        padding: EdgeInsetsDirectional.zero,
        onPressed: () => showOptionsSheet(
          context,
          ref.read(currentSessionStateProvider)!,
          session.event!,
        ),
        icon: const TotemIcon(
          TotemIcons.more,
          color: Colors.white,
        ),
        tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
      ),
    );

    switch (session.resolveCurrentScreen()) {
      case RoomScreen.error:
      case RoomScreen.disconnected:
      case RoomScreen.loading:
        return const SizedBox.shrink();
      case RoomScreen.notMyTurn:
        return ActionBar(
          key: SessionActionBar.actionBarKey,
          children: [
            microphoneButton,
            cameraButton,
            emojiBarButton,
            chatButton,
            moreButton,
          ],
        );
      case RoomScreen.myTurn:
      case RoomScreen.passing:
        return ActionBar(
          key: SessionActionBar.actionBarKey,
          children: [
            microphoneButton,
            cameraButton,
            chatButton,
            moreButton,
          ],
        );
      case RoomScreen.receiving:
        return ActionBar(
          key: SessionActionBar.actionBarKey,
          children: [
            microphoneButton,
            cameraButton,
            chatButton,
            moreButton,
          ],
        );
    }
  }
}
