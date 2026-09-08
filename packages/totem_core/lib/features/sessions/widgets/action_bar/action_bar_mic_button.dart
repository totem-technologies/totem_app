import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/speaking_indicator.dart';
import 'package:totem_core/shared/totem_icons.dart';

class ActionBarMicButton extends StatefulWidget {
  const ActionBarMicButton({
    required this.participant,
    required this.onToggle,
    this.audioTrack,
    this.indicatorColor,
    this.indicatorBarCount = 5,
    super.key,
  });

  final LocalParticipant? participant;
  final AudioTrack? audioTrack;
  final ActionBarButtonToggleCallback? onToggle;
  final Color? indicatorColor;
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
    if (oldWidget.participant?.sid != widget.participant?.sid) {
      _bindListener();
    }
  }

  void _bindListener() {
    _participantListener?.dispose();
    _participantListener = widget.participant?.createListener()
      ?..on<ParticipantEvent>((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _participantListener?.dispose();
    super.dispose();
  }

  TrackPublication<Track>? get _audioPublication {
    return widget.participant?.getTrackPublicationBySource(
      TrackSource.microphone,
    );
  }

  bool get _isMicrophoneEnabled {
    final publication = _audioPublication;
    if (widget.audioTrack == null && publication == null) return false;

    final track = widget.audioTrack ?? publication?.track;
    final isMuted = track?.muted ?? publication?.muted ?? true;
    final isActive = track?.isActive ?? true;
    return isActive && !isMuted;
  }

  Future<void> _toggleMicrophone() async {
    if (_busy) return;

    setState(() => _busy = true);
    try {
      await widget.onToggle?.call(!_isMicrophoneEnabled);
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
      // Live mic stays ghost; cut mic gets the pinkTint "off" circle.
      role: ActionBarButtonRole.media(enabled: isEnabled),
      onPressed: _busy ? null : _toggleMicrophone,
      child: isEnabled
          ? SpeakingIndicatorAudioTrack(
              audioTrack: widget.audioTrack,
              participant: widget.participant,
              // Follow the action-bar ghost color so prejoin cream-on-cream
              // doesn't eat the bars.
              foregroundColor:
                  widget.indicatorColor ??
                  IconTheme.of(context).color ??
                  AppTheme.cream,
              barCount: widget.indicatorBarCount,
            )
          : const TotemIcon(TotemIcons.microphoneOff),
    );
  }
}
