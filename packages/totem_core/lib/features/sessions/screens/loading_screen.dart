import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:shimmer/shimmer.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/features/sessions/widgets/participant_card.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/circle_icon_button.dart';

abstract class PreJoinPreviewTrackFactory {
  const PreJoinPreviewTrackFactory();

  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions cameraOptions,
  );

  Future<LocalAudioTrack?> createAudioTrack();
}

class _LiveKitPreJoinPreviewTrackFactory extends PreJoinPreviewTrackFactory {
  const _LiveKitPreJoinPreviewTrackFactory();

  @override
  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions cameraOptions,
  ) {
    return LocalVideoTrack.createCameraTrack(cameraOptions);
  }

  @override
  Future<LocalAudioTrack?> createAudioTrack() {
    return LocalAudioTrack.create();
  }
}

/// Holds the user's media preferences selected on the pre-join screen.
@immutable
class MediaPreferences {
  const MediaPreferences({
    this.isSpeakerOn = true,
    this.isCameraOn = true,
    this.isMicOn = true,
    this.cameraOptions = SessionController.defaultCameraCaptureOptions,
  });

  final bool isSpeakerOn;
  final bool isCameraOn;
  final bool isMicOn;
  final CameraCaptureOptions cameraOptions;

  MediaPreferences copyWith({
    bool? isSpeakerOn,
    bool? isCameraOn,
    bool? isMicOn,
    CameraCaptureOptions? cameraOptions,
  }) {
    return MediaPreferences(
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      isMicOn: isMicOn ?? this.isMicOn,
      cameraOptions: cameraOptions ?? this.cameraOptions,
    );
  }

  @override
  String toString() {
    return 'MediaPreferences(isSpeakerOn: $isSpeakerOn, isCameraOn: $isCameraOn, isMicOn: $isMicOn, cameraOptions: $cameraOptions)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MediaPreferences &&
        other.isSpeakerOn == isSpeakerOn &&
        other.isCameraOn == isCameraOn &&
        other.isMicOn == isMicOn &&
        other.cameraOptions == cameraOptions;
  }

  @override
  int get hashCode {
    return isSpeakerOn.hashCode ^
        isCameraOn.hashCode ^
        isMicOn.hashCode ^
        cameraOptions.hashCode;
  }
}

class PrejoinSessionScreen extends StatefulWidget {
  const PrejoinSessionScreen({
    this.joinCard,
    PreJoinPreviewTrackFactory? previewTrackFactory,
    this.locked = false,
    this.onMediaPreferencesChanged,
    super.key,
  }) : previewTrackFactory =
           previewTrackFactory ?? const _LiveKitPreJoinPreviewTrackFactory();

  final Widget? joinCard;

  final PreJoinPreviewTrackFactory previewTrackFactory;

  /// Whether the buttons should not perform any actions;
  final bool locked;

  /// Called whenever the user changes their media preferences (camera, mic,
  /// speaker, or camera options).
  final ValueChanged<MediaPreferences>? onMediaPreferencesChanged;

  @override
  State<PrejoinSessionScreen> createState() => _PrejoinSessionScreenState();
}

class _PrejoinSessionScreenState extends State<PrejoinSessionScreen> {
  // Preview media state
  LocalVideoTrack? _previewVideoTrack;
  var _isCameraOn = true;

  LocalAudioTrack? _previewAudioTrack;
  var _isMicOn = true;

  // Join configuration state
  CameraCaptureOptions _cameraOptions =
      SessionController.defaultCameraCaptureOptions;
  var _audioOutputOptions = const AudioOutputOptions(speakerOn: true);
  bool get _isSpeakerOn => _audioOutputOptions.speakerOn ?? false;

  void _notifyMediaPreferencesChanged() {
    widget.onMediaPreferencesChanged?.call(
      MediaPreferences(
        isSpeakerOn: _isSpeakerOn,
        isCameraOn: _isCameraOn,
        isMicOn: _isMicOn,
        cameraOptions: _cameraOptions,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeLocalVideo();
    _initializeLocalAudio();
    _detectHeadphones();
  }

  @override
  void dispose() {
    _disposePreviewTracks();
    super.dispose();
  }

  Future<void> _detectHeadphones() async {
    try {
      final session = await AudioSession.instance;
      final devices = await session.getDevices(includeInputs: false);
      final hasExternalOutput = devices.any(
        (d) =>
            SessionDeviceController.externalAudioOutputTypes.contains(d.type),
      );
      final speakerOn = !hasExternalOutput;

      if (!mounted) return;
      setState(() {
        _audioOutputOptions = AudioOutputOptions(speakerOn: speakerOn);
      });
      _notifyMediaPreferencesChanged();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to detect audio output devices',
      );
    }
  }

  // ===== Preview Tracks =====

  Future<void> _initializeLocalVideo() async {
    await _disposePreviewVideoTrack();

    try {
      final track = await widget.previewTrackFactory.createVideoTrack(
        _cameraOptions,
      );
      if (!mounted) {
        await track?.stop();
        await track?.dispose();
        return;
      }
      _previewVideoTrack = track;
      await _previewVideoTrack?.start();
    } catch (error, stackTrace) {
      _isCameraOn = false;
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to create local video track',
      );
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<LocalAudioTrack?> _initializeLocalAudio() async {
    await _disposePreviewAudioTrack();

    try {
      final track = await widget.previewTrackFactory.createAudioTrack();
      if (!mounted) {
        await track?.stop();
        await track?.dispose();
        return null;
      }
      _previewAudioTrack = track;
      await _previewAudioTrack?.enable();
      await _previewAudioTrack?.start();
      return _previewAudioTrack;
    } catch (error, stackTrace) {
      _isMicOn = false;
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to create local audio track',
      );
    } finally {
      if (mounted) setState(() {});
    }
    return null;
  }

  Future<void> _disposePreviewVideoTrack() async {
    if (_previewVideoTrack != null) {
      try {
        await _previewVideoTrack?.stop();
      } catch (e) {
        ErrorHandler.logError(e, message: 'Failed to stop preview track');
      }

      try {
        await _previewVideoTrack?.dispose();
      } catch (e) {
        ErrorHandler.logError(e, message: 'Failed to dispose preview track');
      } finally {
        _previewVideoTrack = null;
      }
    }
  }

  Future<void> _disposePreviewAudioTrack() async {
    if (_previewAudioTrack != null) {
      try {
        await _previewAudioTrack?.stop();
      } catch (e) {
        ErrorHandler.logError(e, message: 'Failed to stop preview audio track');
      }
      try {
        await _previewAudioTrack?.dispose();
      } catch (e) {
        ErrorHandler.logError(
          e,
          message: 'Failed to dispose preview audio track',
        );
      } finally {
        _previewAudioTrack = null;
      }
    }
  }

  Future<void> _disposePreviewTracks() async {
    await Future.wait([
      _disposePreviewVideoTrack(),
      _disposePreviewAudioTrack(),
    ]);
  }

  // ===== Local controls =====

  Future<void> _toggleCamera() async {
    if (_isCameraOn) {
      setState(() => _isCameraOn = false);
      _notifyMediaPreferencesChanged();
      await _disposePreviewVideoTrack();
      if (mounted) setState(() {});
    } else {
      await _initializeLocalVideo();
      if (mounted) {
        setState(() => _isCameraOn = true);
        _notifyMediaPreferencesChanged();
      }
    }
  }

  Future<void> _toggleMic() async {
    setState(() => _isMicOn = !_isMicOn);
    _notifyMediaPreferencesChanged();
    final track = await _initializeLocalAudio();
    switch (_isMicOn) {
      case true:
        await track?.unmute(stopOnMute: false);
      case false:
        await track?.mute(stopOnMute: false);
    }
  }

  void _toggleSpeaker() {
    setState(() {
      _audioOutputOptions = AudioOutputOptions(speakerOn: !_isSpeakerOn);
    });
    _notifyMediaPreferencesChanged();
  }

  @override
  Widget build(BuildContext context) {
    return RoomBackground(
      child: Builder(
        builder: (context) {
          return SafeArea(
            child: Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                systemOverlayStyle: SystemUiOverlayStyle.dark,
                leading: CircleIconButton(
                  margin: const EdgeInsetsDirectional.only(start: 20, top: 20),
                  icon: TotemIcons.arrowBack,
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).backButtonTooltip,
                  onPressed: () => TotemRouter.instance.popOrHome(context),
                ),
              ),
              extendBodyBehindAppBar: false,
              body: Padding(
                padding: const EdgeInsetsDirectional.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 18,
                  children: [
                    Expanded(
                      child: Container(
                        margin: const EdgeInsetsDirectional.symmetric(
                          horizontal: 40,
                          // vertical: 10,
                        ),
                        alignment: AlignmentDirectional.center,
                        child: Semantics(
                          label:
                              'Your video preview, camera ${_isCameraOn ? 'on' : 'off'}',
                          image: true,
                          child: LocalParticipantCard(
                            isCameraOn: _isCameraOn,
                            audioTrack: _previewAudioTrack,
                            videoTrack: _previewVideoTrack,
                          ),
                        ),
                      ),
                    ),
                    // SizedBox needed to maintain padding with and without it.
                    widget.joinCard ?? const SizedBox(),
                    PrejoinActionBar(
                      locked: widget.locked,
                      previewAudioTrack: _previewAudioTrack,
                      onToggleMic: _toggleMic,
                      isSpeakerOn: _isSpeakerOn,
                      onToggleSpeaker: _toggleSpeaker,
                      isCameraOn: _isCameraOn,
                      onToggleCamera: _toggleCamera,
                      cameraPosition: _cameraOptions.cameraPosition,
                      selectedCameraDeviceId: _cameraOptions.deviceId,
                      onCameraPositionChanged: (position) {
                        setState(() {
                          _cameraOptions = _cameraOptions.copyWith(
                            cameraPosition: position,
                          );
                        });
                        _notifyMediaPreferencesChanged();
                        _initializeLocalVideo();
                      },
                      onCameraDeviceSelected: (device) {
                        setState(() {
                          _cameraOptions = _cameraOptions.copyWith(
                            deviceId: device.deviceId,
                          );
                        });
                        _notifyMediaPreferencesChanged();
                        _initializeLocalVideo();
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class LoadingVideoPlaceholder extends StatelessWidget {
  const LoadingVideoPlaceholder({super.key, this.borderRadius});

  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade500,
      period: const Duration(seconds: 1),
      direction: Directionality.of(context) == TextDirection.ltr
          ? ShimmerDirection.ltr
          : ShimmerDirection.rtl,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(borderRadius ?? 28),
        ),
      ),
    );
  }
}
