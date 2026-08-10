import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
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

@immutable
class PreJoinMediaStatus {
  const PreJoinMediaStatus({
    required this.cameraInitializationComplete,
    required this.microphoneInitializationComplete,
    required this.cameraPermissionGranted,
    required this.microphonePermissionGranted,
    this.cameraError,
    this.microphoneError,
  });

  const PreJoinMediaStatus.initial()
    : cameraInitializationComplete = false,
      microphoneInitializationComplete = false,
      cameraPermissionGranted = false,
      microphonePermissionGranted = false,
      cameraError = null,
      microphoneError = null;

  final bool cameraInitializationComplete;
  final bool microphoneInitializationComplete;
  final bool cameraPermissionGranted;
  final bool microphonePermissionGranted;
  final Object? cameraError;
  final Object? microphoneError;

  bool get initializationComplete =>
      cameraInitializationComplete && microphoneInitializationComplete;

  bool get requiredPermissionsGranted =>
      cameraPermissionGranted && microphonePermissionGranted;
}

/// Coordinates the pre-join preview with the Session join flow without
/// exposing the widget's State object.
class PreJoinMediaController {
  Object? _owner;
  AsyncValueGetter<SessionJoinMedia>? _takeForJoin;
  AsyncValueGetter<PreJoinMediaStatus>? _retryFailedMedia;
  AsyncValueGetter<PreJoinMediaStatus>? _resetAfterFailedJoin;

  void _attach({
    required Object owner,
    required AsyncValueGetter<SessionJoinMedia> takeForJoin,
    required AsyncValueGetter<PreJoinMediaStatus> retryFailedMedia,
    required AsyncValueGetter<PreJoinMediaStatus> resetAfterFailedJoin,
  }) {
    _owner = owner;
    _takeForJoin = takeForJoin;
    _retryFailedMedia = retryFailedMedia;
    _resetAfterFailedJoin = resetAfterFailedJoin;
  }

  void _detach(Object owner) {
    if (identical(_owner, owner)) {
      _owner = null;
      _takeForJoin = null;
      _retryFailedMedia = null;
      _resetAfterFailedJoin = null;
    }
  }

  Future<SessionJoinMedia> takeForJoin() {
    final takeForJoin = _takeForJoin;
    if (takeForJoin == null) {
      throw StateError('Pre-join media is not available');
    }
    return takeForJoin();
  }

  Future<PreJoinMediaStatus> retryFailedMedia() {
    final retryFailedMedia = _retryFailedMedia;
    if (retryFailedMedia == null) {
      throw StateError('Pre-join media is not available');
    }
    return retryFailedMedia();
  }

  /// Releases the one-shot transfer state after the failed room has been
  /// disposed and creates fresh preview tracks for another join attempt.
  Future<PreJoinMediaStatus> resetAfterFailedJoin() {
    final resetAfterFailedJoin = _resetAfterFailedJoin;
    if (resetAfterFailedJoin == null) {
      throw StateError('Pre-join media is not available');
    }
    return resetAfterFailedJoin();
  }
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
    this.mediaController,
    this.locked = false,
    this.onMediaPreferencesChanged,
    this.onMediaStatusChanged,
    super.key,
  }) : previewTrackFactory =
           previewTrackFactory ?? const _LiveKitPreJoinPreviewTrackFactory();

  final Widget? joinCard;

  final PreJoinPreviewTrackFactory previewTrackFactory;

  final PreJoinMediaController? mediaController;

  /// Whether the buttons should not perform any actions;
  final bool locked;

  /// Called whenever the user changes their media preferences (camera, mic,
  /// speaker, or camera options).
  final ValueChanged<MediaPreferences>? onMediaPreferencesChanged;

  /// Called as the real preview tracks acquire camera and microphone access.
  final ValueChanged<PreJoinMediaStatus>? onMediaStatusChanged;

  @override
  State<PrejoinSessionScreen> createState() => _PrejoinSessionScreenState();
}

class _PrejoinSessionScreenState extends State<PrejoinSessionScreen> {
  // Preview media state
  LocalVideoTrack? _previewVideoTrack;
  LocalVideoTrack? _transferredVideoTrack;
  var _isCameraOn = true;

  LocalAudioTrack? _previewAudioTrack;
  LocalAudioTrack? _transferredAudioTrack;
  var _isMicOn = true;

  Future<void>? _mediaInitialization;
  Future<void>? _cameraOperation;
  Future<void>? _microphoneOperation;
  var _cameraInitializationComplete = false;
  var _microphoneInitializationComplete = false;
  var _cameraPermissionGranted = false;
  var _microphonePermissionGranted = false;
  Object? _cameraError;
  Object? _microphoneError;
  var _mediaTransferred = false;

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

  PreJoinMediaStatus get _mediaStatus => PreJoinMediaStatus(
    cameraInitializationComplete: _cameraInitializationComplete,
    microphoneInitializationComplete: _microphoneInitializationComplete,
    cameraPermissionGranted: _cameraPermissionGranted,
    microphonePermissionGranted: _microphonePermissionGranted,
    cameraError: _cameraError,
    microphoneError: _microphoneError,
  );

  void _notifyMediaStatusChanged() {
    widget.onMediaStatusChanged?.call(_mediaStatus);
  }

  @override
  void initState() {
    super.initState();
    widget.mediaController?._attach(
      owner: this,
      takeForJoin: _takeMediaForJoin,
      retryFailedMedia: _retryFailedMedia,
      resetAfterFailedJoin: _resetAfterFailedJoin,
    );
    _mediaInitialization = _initializePreviewMedia();
    _detectHeadphones();
  }

  @override
  void didUpdateWidget(covariant PrejoinSessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.mediaController, widget.mediaController)) {
      oldWidget.mediaController?._detach(this);
      widget.mediaController?._attach(
        owner: this,
        takeForJoin: _takeMediaForJoin,
        retryFailedMedia: _retryFailedMedia,
        resetAfterFailedJoin: _resetAfterFailedJoin,
      );
    }
  }

  @override
  void dispose() {
    widget.mediaController?._detach(this);
    unawaited(_disposePreviewTracks());
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

  Future<void> _initializePreviewMedia() async {
    // Initialize sequentially. In particular, Safari is sensitive to
    // overlapping getUserMedia calls during a cold browser start.
    if (_isCameraOn) {
      await _startCameraInitialization();
    } else {
      _cameraInitializationComplete = true;
      _cameraPermissionGranted = true;
      _notifyMediaStatusChanged();
    }

    // Re-read the preference after camera initialization. The user may have
    // disabled the microphone while the camera request was in flight.
    if (_isMicOn) {
      await _startMicrophoneInitialization();
    } else {
      _microphoneInitializationComplete = true;
      _microphonePermissionGranted = true;
      _notifyMediaStatusChanged();
    }
  }

  Future<void> _startCameraInitialization() {
    return _queueCameraOperation(_initializeLocalVideo);
  }

  Future<LocalAudioTrack?> _startMicrophoneInitialization() {
    return _queueMicrophoneOperation(_initializeLocalAudio);
  }

  Future<void> _stopCameraPreview() {
    return _queueCameraOperation(_disposePreviewVideoTrack);
  }

  Future<void> _queueCameraOperation(Future<void> Function() operation) {
    final previous = _cameraOperation;
    final next = () async {
      await previous;
      await operation();
    }();
    _cameraOperation = next;
    return next;
  }

  Future<void> _stopMicrophonePreview() {
    return _queueMicrophoneOperation(_disposePreviewAudioTrack);
  }

  Future<T> _queueMicrophoneOperation<T>(Future<T> Function() operation) {
    final previous = _microphoneOperation;
    final next = () async {
      await previous;
      return operation();
    }();
    _microphoneOperation = next;
    return next;
  }

  Future<void> _initializeLocalVideo() async {
    await _disposePreviewVideoTrack();
    _cameraPermissionGranted = false;

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
      _cameraPermissionGranted = track != null;
      _cameraError = null;
    } catch (error, stackTrace) {
      _isCameraOn = false;
      _cameraError = error;
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to create local video track',
      );
    } finally {
      _cameraInitializationComplete = true;
      _notifyMediaStatusChanged();
      if (mounted) setState(() {});
    }
  }

  Future<LocalAudioTrack?> _initializeLocalAudio() async {
    await _disposePreviewAudioTrack();
    _microphonePermissionGranted = false;

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
      _microphonePermissionGranted = track != null;
      _microphoneError = null;
      return _previewAudioTrack;
    } catch (error, stackTrace) {
      _isMicOn = false;
      _microphoneError = error;
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to create local audio track',
      );
    } finally {
      _microphoneInitializationComplete = true;
      _notifyMediaStatusChanged();
      if (mounted) setState(() {});
    }
    return null;
  }

  Future<void> _disposePreviewVideoTrack() async {
    final track = _previewVideoTrack;
    if (track != null) {
      if (identical(track, _transferredVideoTrack)) return;
      try {
        await track.stop();
      } catch (e) {
        ErrorHandler.logError(e, message: 'Failed to stop preview track');
      }

      try {
        await track.dispose();
      } catch (e) {
        ErrorHandler.logError(e, message: 'Failed to dispose preview track');
      } finally {
        _previewVideoTrack = null;
      }
    }
  }

  Future<void> _disposePreviewAudioTrack() async {
    final track = _previewAudioTrack;
    if (track != null) {
      if (identical(track, _transferredAudioTrack)) return;
      try {
        await track.stop();
      } catch (e) {
        ErrorHandler.logError(e, message: 'Failed to stop preview audio track');
      }
      try {
        await track.dispose();
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
      _stopCameraPreview(),
      _stopMicrophonePreview(),
    ]);
  }

  Future<SessionJoinMedia> _takeMediaForJoin() async {
    if (_mediaTransferred) {
      throw StateError('Pre-join media has already been transferred');
    }

    await _mediaInitialization;
    await Future.wait([
      ?_cameraOperation,
      ?_microphoneOperation,
    ]);

    final cameraTrack = _isCameraOn ? _previewVideoTrack : null;
    final microphoneTrack = _isMicOn ? _previewAudioTrack : null;
    _transferredVideoTrack = cameraTrack;
    _transferredAudioTrack = microphoneTrack;
    _mediaTransferred = true;

    return SessionJoinMedia(
      cameraTrack: cameraTrack,
      microphoneTrack: microphoneTrack,
    );
  }

  Future<PreJoinMediaStatus> _retryFailedMedia() async {
    await _mediaInitialization;
    if (_mediaTransferred) return _mediaStatus;

    Future<void> retry() async {
      if (!_cameraPermissionGranted) {
        _cameraInitializationComplete = false;
        _isCameraOn = true;
        await _startCameraInitialization();
      }
      if (!_microphonePermissionGranted) {
        _microphoneInitializationComplete = false;
        _isMicOn = true;
        await _startMicrophoneInitialization();
      }
    }

    _mediaInitialization = retry();
    await _mediaInitialization;
    _notifyMediaPreferencesChanged();
    return _mediaStatus;
  }

  Future<PreJoinMediaStatus> _resetAfterFailedJoin() async {
    await _mediaInitialization;
    await Future.wait([
      ?_cameraOperation,
      ?_microphoneOperation,
    ]);

    // The failed Session/Room teardown owns the transferred tracks. Drop all
    // preview references without stopping them here, then acquire fresh media.
    _previewVideoTrack = null;
    _previewAudioTrack = null;
    _transferredVideoTrack = null;
    _transferredAudioTrack = null;
    _mediaTransferred = false;

    _cameraInitializationComplete = !_isCameraOn;
    _microphoneInitializationComplete = !_isMicOn;
    _cameraError = null;
    _microphoneError = null;

    Future<void> reinitialize() async {
      // Keep capture requests sequential for cold-start Safari.
      if (_isCameraOn) await _startCameraInitialization();
      if (_isMicOn) await _startMicrophoneInitialization();
    }

    _mediaInitialization = reinitialize();
    await _mediaInitialization;
    _notifyMediaPreferencesChanged();
    _notifyMediaStatusChanged();
    if (mounted) setState(() {});
    return _mediaStatus;
  }

  // ===== Local controls =====

  bool _isTogglingCamera = false;

  Future<void> _toggleCamera() async {
    if (_isTogglingCamera) return;
    _isTogglingCamera = true;

    try {
      if (_isCameraOn) {
        setState(() => _isCameraOn = false);
        _notifyMediaPreferencesChanged();
        await _stopCameraPreview();
        if (mounted) setState(() {});
      } else {
        await _startCameraInitialization();
        if (mounted) {
          setState(() => _isCameraOn = true);
          _notifyMediaPreferencesChanged();
        }
      }
    } finally {
      _isTogglingCamera = false;
    }
  }

  bool _isTogglingMic = false;

  Future<void> _toggleMic() async {
    if (_isTogglingMic) return;
    _isTogglingMic = true;

    try {
      setState(() => _isMicOn = !_isMicOn);
      _notifyMediaPreferencesChanged();

      if (_isMicOn) {
        final track = await _startMicrophoneInitialization();
        await track?.unmute(stopOnMute: false);
      } else {
        await _stopMicrophonePreview();
        if (mounted) setState(() {});
      }
    } finally {
      _isTogglingMic = false;
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
                        if (_isCameraOn) {
                          unawaited(_startCameraInitialization());
                        }
                      },
                      onCameraDeviceSelected: (device) {
                        setState(() {
                          _cameraOptions = _cameraOptions.copyWith(
                            deviceId: device.deviceId,
                          );
                        });
                        _notifyMediaPreferencesChanged();
                        if (_isCameraOn) {
                          unawaited(_startCameraInitialization());
                        }
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
