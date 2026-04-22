import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_app/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_app/features/sessions/widgets/speaking_indicator.dart';
import 'package:totem_app/shared/totem_icons.dart';

// TODO(web): Microphone should have picker same as camera

class ActionBarMicButton extends StatefulWidget {
  const ActionBarMicButton({
    required this.participant,
    required this.onToggle,
    this.audioTrack,
    this.indicatorColor = Colors.black,
    this.indicatorBarCount = 5,
    super.key,
  });

  final LocalParticipant? participant;
  final AudioTrack? audioTrack;
  final ActionBarButtonToggleCallback? onToggle;
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
      active: isEnabled,
      onPressed: _busy ? null : _toggleMicrophone,
      child: isEnabled
          ? SpeakingIndicatorAudioTrack(
              audioTrack: widget.audioTrack,
              participant: widget.participant,
              foregroundColor: widget.indicatorColor,
              barCount: widget.indicatorBarCount,
            )
          : const TotemIcon(TotemIcons.microphoneOff),
    );
  }
}
