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
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/sessions/repositories/session_repository.dart';
import 'package:totem_app/features/sessions/screens/error_screen.dart';
import 'package:totem_app/features/sessions/screens/loading_screen.dart';
import 'package:totem_app/features/sessions/screens/options_sheet.dart';
import 'package:totem_app/features/sessions/screens/room_screen.dart';
import 'package:totem_app/features/sessions/services/session_service.dart';
import 'package:totem_app/features/sessions/widgets/action_bar.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/features/sessions/widgets/transition_card.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/confirmation_dialog.dart';

class PreJoinScreen extends ConsumerStatefulWidget {
  const PreJoinScreen({required this.sessionSlug, super.key});

  final String sessionSlug;

  @override
  ConsumerState<PreJoinScreen> createState() => _PreJoinScreenState();
}

class _PreJoinScreenState extends ConsumerState<PreJoinScreen> {
  LocalVideoTrack? _previewVideoTrack;
  var _isCameraOn = true;
  var _isMicOn = true;

  CameraCaptureOptions? _cameraOptions;
  var _audioOptions = const AudioCaptureOptions();
  var _audioOutputOptions = const AudioOutputOptions(speakerOn: true);

  SessionOptions? _sessionOptions;
  final GlobalKey actionBarKey = GlobalKey();
  final GlobalKey loadingScreenKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _requestLock = false;
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
    _requestLock = false;
    if (_sessionOptions == null) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  // Do not perform multiple permission requests
  bool _requestLock = false;

  void _initializeAndCheckPermissions() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestPermissions();
      await _detectHeadphones();
      _initializeLocalVideo();
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
        (d) => DevicesControl.externalAudioOutputTypes.contains(d.type),
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

  Future<void> _requestPermissions() async {
    if (_requestLock) return;
    _requestLock = true;

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

      await BackgroundControl.requestPermissions();
    } finally {
      _requestLock = false;
    }
  }

  Future<void> _initializeLocalVideo() async {
    if (_previewVideoTrack != null) {
      await _disposePreviewTrack();
    }

    try {
      _cameraOptions ??= Session.defaultCameraCaptureOptions;
      _previewVideoTrack = await LocalVideoTrack.createCameraTrack(
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

  void _toggleCamera() {
    setState(() => _isCameraOn = !_isCameraOn);
  }

  void _toggleMic() {
    setState(() => _isMicOn = !_isMicOn);
  }

  Widget _buildPrejoinUI() {
    return PrejoinRoomBaseScreen(
      key: loadingScreenKey,
      video: Semantics(
        label: 'Your video preview, camera ${_isCameraOn ? 'on' : 'off'}',
        image: true,
        child: LocalParticipantVideoCard(
          isCameraOn: _isCameraOn,
          videoTrack: _previewVideoTrack,
        ),
      ),

      joinSlider: TransitionCard(
        margin: const EdgeInsetsDirectional.symmetric(horizontal: 10),
        type: TotemCardTransitionType.join,
        keepActionLoadingOnSuccess: true,
        onActionPressed: () async {
          await _joinRoom();
          return true;
        },
      ),
      actionBar: ActionBar(
        key: actionBarKey,
        children: [
          ActionBarButton(
            semanticsLabel: 'Microphone ${_isMicOn ? 'on' : 'off'}',
            onPressed: _sessionOptions == null ? _toggleMic : null,
            active: _isMicOn,
            child: TotemIcon(
              _isMicOn ? TotemIcons.microphoneOn : TotemIcons.microphoneOff,
            ),
          ),
          ActionBarButton(
            semanticsLabel: 'Camera ${_isCameraOn ? 'on' : 'off'}',
            onPressed: _sessionOptions == null ? _toggleCamera : null,
            active: _isCameraOn,
            child: TotemIcon(
              _isCameraOn ? TotemIcons.cameraOn : TotemIcons.cameraOff,
            ),
          ),
          ActionBarButton(
            semanticsLabel: MaterialLocalizations.of(
              context,
            ).moreButtonTooltip,
            onPressed: () async {
              if (_sessionOptions != null) return;
              await showPrejoinOptionsSheet(
                context,
                cameraOptions: _cameraOptions,
                audioOptions: _audioOptions,
                audioOutputOptions: _audioOutputOptions,
                onCameraChanged: (options) async {
                  setState(() {
                    _cameraOptions = options;
                  });
                  await _initializeLocalVideo();
                },
                onAudioChanged: (options) {
                  setState(() => _audioOptions = options);
                },
                onAudioOutputChanged: (options) {
                  setState(() => _audioOutputOptions = options);
                },
              );
            },
            child: const Center(
              child: TotemIcon(TotemIcons.more, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinRoom() async {
    if (_sessionOptions != null) return;

    final token = (await ref.read(
      sessionTokenProvider(widget.sessionSlug).future,
    )).token;
    await ref.read(eventProvider(widget.sessionSlug).future);

    _sessionOptions = SessionOptions(
      eventSlug: widget.sessionSlug,
      token: token,
      cameraEnabled: _isCameraOn,
      microphoneEnabled: _isMicOn,
      cameraOptions: _cameraOptions ?? Session.defaultCameraCaptureOptions,
      audioOptions: _audioOptions,
      audioOutputOptions: _audioOutputOptions,
      onEmojiReceived: (_, _) async {},
      onMessageReceived: (_, _) {},
      onLivekitError: (_) {},
      onKeeperLeaveRoom: (_) => () {},
      onConnected: _onRoomConnected,
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _onRoomConnected() {
    _disposePreviewTrack();
    SentryDisplayWidget.of(context).reportFullyDisplayed();
  }

  Future<void> _disposePreviewTrack() async {
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

  bool _showingAlreadyPresentDialog = false;

  @override
  Widget build(BuildContext context) {
    final tokenData = ref.watch(sessionTokenProvider(widget.sessionSlug));
    final sessionData = ref.watch(eventProvider(widget.sessionSlug));

    ref.listen(sessionTokenProvider(widget.sessionSlug), (
      previous,
      next,
    ) async {
      if (_showingAlreadyPresentDialog) return;
      if (next case AsyncData(:final value) when value.isAlreadyPresent) {
        _showingAlreadyPresentDialog = true;
        final join = await showAlreadyPresentDialog(context);
        _showingAlreadyPresentDialog = false;
        if (join) {
          _joinRoom();
        } else {
          if (context.mounted) {
            context.pop();
          }
        }
      }
    });

    if (tokenData.hasError) {
      return RoomBackground(
        child: RoomErrorScreen(
          error: tokenData.error,
          onRetry: () =>
              ref.refresh(sessionTokenProvider(widget.sessionSlug).future),
        ),
      );
    }

    if (sessionData.hasError) {
      return RoomBackground(
        child: RoomErrorScreen(
          onRetry: () => ref.refresh(eventProvider(widget.sessionSlug).future),
        ),
      );
    }

    final isLoading =
        (tokenData.isLoading && !tokenData.isRefreshing) ||
        (sessionData.isLoading && !sessionData.isRefreshing);
    if (_sessionOptions == null || isLoading) {
      return _buildPrejoinUI();
    }

    final session = sessionData.value!;
    return VideoRoomScreen(
      sessionSlug: widget.sessionSlug,
      sessionOptions: _sessionOptions!,
      session: session,
      loadingScreen: _buildPrejoinUI(),
      actionBarKey: actionBarKey,
    );
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
