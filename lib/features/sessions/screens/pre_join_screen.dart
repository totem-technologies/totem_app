import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart'
    hide Session, SessionOptions;
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_app/features/sessions/controllers/features/session_infra_controller.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/repositories/session_repository.dart';
import 'package:totem_app/features/sessions/screens/error_screen.dart';
import 'package:totem_app/features/sessions/screens/loading_screen.dart';
import 'package:totem_app/features/sessions/screens/room_screen.dart';
import 'package:totem_app/features/sessions/widgets/action_bar.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/features/sessions/widgets/transition_card.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/confirmation_dialog.dart';

@visibleForTesting
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

/// Shows a dialog when the user tries to join a session they are already
/// in on another device, asking if they want to leave the other session
/// and join on this device instead.
///
/// Returns true if the user chooses to leave the other session and join
/// on this device, false otherwise.
Future<bool> showAlreadyPresentDialog(BuildContext context) async {
  try {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return ConfirmationDialog(
              title: "You're Already in This Session",
              content:
                  'You are already in this session on another device. Do you want to leave the other session and join on this device?',
              icon: TotemIcons.questionMarkCircle,
              iconSize: 60,
              confirmButtonText: 'Join Here',
              onConfirm: () async {
                Navigator.of(context).pop(true);
              },
              type: ConfirmationDialogType.standard,
            );
          },
        ) ??
        false;
  } catch (_) {
    return false;
  }
}

class PreJoinScreen extends ConsumerStatefulWidget {
  const PreJoinScreen({
    required this.sessionSlug,
    this.previewTrackFactory = const _LiveKitPreJoinPreviewTrackFactory(),
    super.key,
  });

  final String sessionSlug;
  final PreJoinPreviewTrackFactory previewTrackFactory;

  @override
  ConsumerState<PreJoinScreen> createState() => _PreJoinScreenState();
}

class _PreJoinScreenState extends ConsumerState<PreJoinScreen> {
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

  // Session/join lifecycle state
  SessionOptions? _sessionOptions;
  bool _hasRequestedJoin = false;
  bool get hasRequestedJoin => _hasRequestedJoin;
  bool _hasHandledConnectedState = false;
  bool _showingAlreadyPresentDialog = false;
  bool? _isLoading;

  // Guards concurrent permission prompts.
  bool _permissionsRequestLock = false;

  final GlobalKey _loadingScreenKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _permissionsRequestLock = false;
    _initializeAndCheckPermissions();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    if (_previewVideoTrack != null) {
      _previewVideoTrack!.stop();
      _previewVideoTrack!.dispose();
      _previewVideoTrack = null;
    }
    if (_previewAudioTrack != null) {
      _previewAudioTrack!.stop();
      _previewAudioTrack!.dispose();
      _previewAudioTrack = null;
    }
    _permissionsRequestLock = false;
    if (!hasRequestedJoin) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  // ===== Initialization =====

  void _initializeAndCheckPermissions() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestPermissions();
      await Future.wait([
        _detectHeadphones(),
        _initializeLocalVideo(),
        _initializeLocalAudio(),
      ]);
      if (mounted) {
        SentryDisplayWidget.of(context).reportFullyDisplayed();
      }
    });
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
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to detect audio output devices',
      );
    }
  }

  // ===== Permissions =====

  Future<void> _requestPermissions() async {
    if (_permissionsRequestLock) return;
    _permissionsRequestLock = true;

    try {
      final statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      final cameraStatus =
          statuses[Permission.camera] ?? PermissionStatus.denied;
      final micStatus =
          statuses[Permission.microphone] ?? PermissionStatus.denied;

      if (!cameraStatus.isGranted || !micStatus.isGranted) {
        if (!mounted) return;

        final missing = <String>[];
        if (!cameraStatus.isGranted) missing.add('Camera');
        if (!micStatus.isGranted) missing.add('Microphone');

        final isPermanent =
            cameraStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied;

        await showAdaptiveDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog.adaptive(
            title: const Text('Permissions Required'),
            content: Text(
              '${missing.join(' and ')} access is required. ${isPermanent ? 'Please enable them in System Settings.' : 'Please grant these permissions to continue.'}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  isPermanent ? openAppSettings() : _requestPermissions();
                },
                child: Text(isPermanent ? 'Open Settings' : 'Try Again'),
              ),
            ],
          ),
        );
      }

      await SessionInfraController.requestPermissions();
    } finally {
      _permissionsRequestLock = false;
    }
  }

  Future<void> _initializeLocalVideo() async {
    if (_previewVideoTrack != null) {
      await _disposePreviewVideoTrack();
    }

    try {
      _previewVideoTrack = await widget.previewTrackFactory.createVideoTrack(
        _cameraOptions,
      );
      await _previewVideoTrack!.start();
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
    if (_previewAudioTrack != null) {
      await _disposePreviewAudioTrack();
    }

    try {
      _previewAudioTrack = await widget.previewTrackFactory.createAudioTrack();
      await _previewAudioTrack!.enable();
      await _previewAudioTrack!.start();
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

  // ===== Local controls =====

  void _toggleCamera() {
    setState(() => _isCameraOn = !_isCameraOn);
  }

  Future<void> _toggleMic() async {
    setState(() => _isMicOn = !_isMicOn);
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
  }

  // ===== UI =====

  Widget _buildPrejoinUI() {
    return PrejoinRoomBaseScreen(
      key: _loadingScreenKey,
      video: Semantics(
        label: 'Your video preview, camera ${_isCameraOn ? 'on' : 'off'}',
        image: true,
        child: LocalParticipantCard(
          isCameraOn: _isCameraOn,
          audioTrack: _previewAudioTrack,
          videoTrack: _previewVideoTrack,
        ),
      ),

      joinSlider: TransitionCard(
        margin: const EdgeInsetsDirectional.symmetric(horizontal: 10),
        type: TotemCardTransitionType.join,
        keepActionLoadingOnSuccess: true,
        onActionPressed: () async {
          await _joinRoom();
          return _hasRequestedJoin;
        },
        isSliderLoading: _isLoading,
      ),
      actionBar: ActionBar(
        key: SessionActionBar.actionBarKey,
        children: [
          ActionBarMicButton(
            participant: null,
            audioTrack: _previewAudioTrack,
            onToggle: (v) async => _toggleMic(),
          ),
          ActionBarButton(
            semanticsLabel: 'Audio ${_isSpeakerOn ? 'on' : 'off'}',
            onPressed: !hasRequestedJoin ? _toggleSpeaker : null,
            active: _isSpeakerOn,
            child: TotemIcon(
              _isSpeakerOn ? TotemIcons.speakerOn : TotemIcons.speakerOff,
            ),
          ),
          ActionBarCameraSwitcherButton(
            isCameraOn: _isCameraOn,
            onToggle: hasRequestedJoin ? null : _toggleCamera,
            cameraPosition: _cameraOptions.cameraPosition,
            onCameraPositionChanged: (position) {
              setState(() {
                _cameraOptions = _cameraOptions.copyWith(
                  cameraPosition: position,
                );
              });
              _initializeLocalVideo();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(Object? error) {
    return RoomBackground(
      child: RoomErrorScreen(
        error: error,
        onRetry: _onRetry,
      ),
    );
  }

  // ===== Join flow =====

  Future<void> _handleToken(
    JoinResponse response, {
    bool shouldShowAlreadyPresentDialog = true,
  }) async {
    _sessionOptions = SessionOptions(
      eventSlug: widget.sessionSlug,
      token: response.token,
      cameraEnabled: _isCameraOn,
      microphoneEnabled: _isMicOn,
      cameraOptions: _cameraOptions,
      audioOutputOptions: _audioOutputOptions,
    );
    if (mounted) setState(() {});

    if (hasRequestedJoin || !mounted) return;
    if (response.isAlreadyPresent &&
        shouldShowAlreadyPresentDialog &&
        !_showingAlreadyPresentDialog) {
      _showingAlreadyPresentDialog = true;
      final join = await showAlreadyPresentDialog(context);
      _showingAlreadyPresentDialog = false;
      if (join) {
        await _joinRoom(showAlreadyPresentDialog: false);
      } else {
        if (mounted) context.pop();
      }
    }
  }

  Future<void> _joinRoom({bool showAlreadyPresentDialog = true}) async {
    try {
      final response = await ref.read(
        sessionTokenProvider(widget.sessionSlug).future,
      );
      await _handleToken(
        response,
        shouldShowAlreadyPresentDialog: showAlreadyPresentDialog,
      );

      if (hasRequestedJoin || _showingAlreadyPresentDialog) return;
      _hasRequestedJoin = true;

      final options = _sessionOptions!;

      setState(() => _isLoading = true);

      await ref.read(eventProvider(widget.sessionSlug).future);
      final session = ref.read(sessionControllerProvider(options).notifier)
        ..configureJoinPreferences(
          cameraEnabled: _isCameraOn,
          microphoneEnabled: _isMicOn,
        );
      await session.join();
      _hasHandledConnectedState = _isLoading = false;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to join room',
      );
    } finally {
      _isLoading = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _onRetry() async {
    setState(() => _isLoading = null);
    final _ = await ref.refresh(
      sessionTokenProvider(widget.sessionSlug).future,
    );
    final _ = await ref.refresh(eventProvider(widget.sessionSlug).future);
  }

  // ===== Track disposal =====

  Future<void> _disposePreviewVideoTrack() async {
    if (_previewVideoTrack != null) {
      try {
        await _previewVideoTrack!.stop();
      } catch (e) {
        ErrorHandler.logError(e, message: 'Failed to stop preview track');
      }

      try {
        await _previewVideoTrack!.dispose();
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
        await _previewAudioTrack!.stop();
      } catch (e) {
        ErrorHandler.logError(e, message: 'Failed to stop preview audio track');
      }
      try {
        await _previewAudioTrack!.dispose();
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

  // ===== Provider listeners =====

  void _listenForTokenUpdates() {
    ref.listen(
      sessionTokenProvider(widget.sessionSlug),
      (previous, next) async {
        if (next case AsyncData(:final value)) {
          _handleToken(value);
        }
      },
    );
  }

  void _listenForConnectedState() {
    final options = _sessionOptions;
    if (options == null) return;

    ref.listen(
      sessionProvider(options).select((s) => s.connectionState),
      (previous, next) {
        if (_hasHandledConnectedState) return;
        if (next != RoomConnectionState.connected) return;

        _hasHandledConnectedState = true;
        _disposePreviewTracks();
        SentryDisplayWidget.of(context).reportFullyDisplayed();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokenData = ref.watch(sessionTokenProvider(widget.sessionSlug));
    final sessionData = ref.watch(eventProvider(widget.sessionSlug));

    _listenForTokenUpdates();
    _listenForConnectedState();

    if (tokenData.hasError) {
      return _buildErrorScreen(tokenData.error);
    }

    if (sessionData.hasError) {
      return _buildErrorScreen(sessionData.error);
    }

    final isLoading =
        (tokenData.isLoading && !tokenData.isRefreshing) ||
        (sessionData.isLoading && !sessionData.isRefreshing);

    if (!hasRequestedJoin || isLoading) {
      return _buildPrejoinUI();
    }

    return ProviderScope(
      overrides: [
        sessionScopeProvider.overrideWith((ref) => _sessionOptions!),
      ],
      child: VideoRoomScreen(
        sessionSlug: widget.sessionSlug,
        loadingScreen: _buildPrejoinUI(),
      ),
    );
  }
}
