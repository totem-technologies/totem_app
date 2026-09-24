import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart';

import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/speaking_indicator.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';

class ActionBarMicButton extends StatefulWidget {
  const ActionBarMicButton({
    required this.participant,
    required this.onToggle,
    this.audioTrack,
    this.initiallyEnabled,
    this.isMicOn,
    this.requiresUnmuteConfirmation = false,
    this.indicatorColor,
    this.indicatorBarCount = 5,
    super.key,
  });

  final LocalParticipant? participant;
  final AudioTrack? audioTrack;
  final bool? initiallyEnabled;

  /// When non-null, drives the displayed state directly and makes the button
  /// controlled (e.g. the pre-join screen, where the selected preference is the
  /// source of truth while the preview track is still initializing).
  final bool? isMicOn;
  final bool requiresUnmuteConfirmation;
  final ActionBarButtonToggleCallback? onToggle;
  final Color? indicatorColor;
  final int indicatorBarCount;

  @override
  State<ActionBarMicButton> createState() => _ActionBarMicButtonState();
}

class _ActionBarMicButtonState extends State<ActionBarMicButton> {
  EventsListener<ParticipantEvent>? _participantListener;
  bool _busy = false;
  late bool _microphoneIsEnabled = _initialMicrophoneEnabled();

  @override
  void initState() {
    super.initState();
    _bindListener();
  }

  @override
  void didUpdateWidget(covariant ActionBarMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant?.sid != widget.participant?.sid) {
      _microphoneIsEnabled = _initialMicrophoneEnabled();
      _bindListener();
    }
  }

  void _bindListener() {
    _participantListener?.dispose();
    _participantListener = widget.participant?.createListener();
    _participantListener
      ?..on<TrackPublishedEvent>(
        (event) => _onMicrophonePublicationChanged(event.publication),
      )
      ..on<TrackUnpublishedEvent>(
        (event) => _onMicrophonePublicationChanged(event.publication),
      )
      ..on<LocalTrackPublishedEvent>(
        (event) => _onMicrophonePublicationChanged(event.publication),
      )
      ..on<LocalTrackUnpublishedEvent>(
        (event) => _onMicrophonePublicationChanged(event.publication),
      )
      ..on<TrackMutedEvent>(
        (event) => _onMicrophonePublicationChanged(event.publication),
      )
      ..on<TrackUnmutedEvent>(
        (event) => _onMicrophonePublicationChanged(event.publication),
      );
  }

  void _onMicrophonePublicationChanged(TrackPublication<Track> publication) {
    if (!mounted || publication.source != TrackSource.microphone) return;
    if (widget.isMicOn != null) return;
    setState(() => _microphoneIsEnabled = _isPublicationEnabled(publication));
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

  bool _initialMicrophoneEnabled() {
    if (widget.isMicOn != null) return widget.isMicOn!;

    final publication = _audioPublication;
    if (widget.audioTrack != null || publication != null) {
      return _microphoneEnabledFromMedia();
    }

    return widget.initiallyEnabled ?? false;
  }

  bool _microphoneEnabledFromMedia() {
    final publication = _audioPublication;
    if (widget.audioTrack == null && publication == null) return false;

    final track = widget.audioTrack ?? publication?.track;
    final isMuted = track?.muted ?? publication?.muted ?? true;
    final isActive = track?.isActive ?? true;
    return isActive && !isMuted;
  }

  bool _isPublicationEnabled(TrackPublication<Track> publication) {
    final track = publication.track;
    final isMuted = track?.muted ?? publication.muted;
    final isActive = track?.isActive ?? true;
    return isActive && !isMuted;
  }

  bool get _isEnabled => widget.isMicOn ?? _microphoneIsEnabled;

  Future<void> _toggleMicrophone() async {
    if (_busy) return;

    setState(() => _busy = true);
    try {
      final shouldEnable = !_isEnabled;
      if (shouldEnable && widget.requiresUnmuteConfirmation) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => ConfirmationDialog(
            content:
                'Someone else has the Totem.\n'
                'Are you sure you want to unmute?',
            confirmButtonText: 'Unmute Anyway',
            type: ConfirmationDialogType.standard,
            showCancel: false,
            onConfirm: () async => Navigator.of(dialogContext).pop(true),
            extraButtons: [
              ConfirmationDialogButton.outlined(
                onConfirm: () async => Navigator.of(dialogContext).pop(false),
                child: const Text('Stay Muted'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }

      await widget.onToggle?.call(shouldEnable);
      if (mounted) setState(() => _microphoneIsEnabled = shouldEnable);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = _isEnabled;

    return ActionBarButton(
      semanticsLabel: 'Microphone ${isEnabled ? 'on' : 'off'}',
      role: ActionBarButtonRole.media(enabled: isEnabled),
      onPressed: _busy ? null : _toggleMicrophone,
      child: isEnabled
          ? Builder(
              builder: (context) {
                if (widget.audioTrack == null && _audioPublication == null) {
                  return const TotemIcon(TotemIcons.microphoneOn);
                }
                return SpeakingIndicatorAudioTrack(
                  audioTrack: widget.audioTrack,
                  participant: widget.participant,
                  // Follow the action-bar ghost color so prejoin cream-on-cream
                  // doesn't eat the bars.
                  foregroundColor:
                      widget.indicatorColor ??
                      IconTheme.of(context).color ??
                      AppTheme.cream,
                  iconSize: IconTheme.of(context).size ?? 20,
                  barCount: widget.indicatorBarCount,
                );
              },
            )
          : const TotemIcon(TotemIcons.microphoneOff),
    );
  }
}
