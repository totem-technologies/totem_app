import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart' hide Session;
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
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/totem_icons.dart';

class PreJoinScreen extends ConsumerStatefulWidget {
  const PreJoinScreen({required this.eventSlug, super.key});

  final String eventSlug;

  @override
  ConsumerState<PreJoinScreen> createState() => _PreJoinScreenState();
}

class _PreJoinScreenState extends ConsumerState<PreJoinScreen> {
  LocalVideoTrack? _videoTrack;
  var _isCameraOn = true;
  var _isMicOn = true;

  CameraCaptureOptions? _cameraOptions;
  var _audioOptions = const AudioCaptureOptions();
  var _audioOutputOptions = const AudioOutputOptions();

  @override
  void initState() {
    super.initState();
    _requestLock = false;
    _initializeAndCheckPermissions();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    if (_videoTrack != null) {
      _videoTrack!.stop();
      _videoTrack!.dispose();
      _videoTrack = null;
    }
    _requestLock = false;
    if (!_joined) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  // Do not perform multiple permission requests
  bool _requestLock = false;

  void _initializeAndCheckPermissions() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestPermissions();
      if (await Permission.camera.isGranted &&
          await Permission.microphone.isGranted) {
        _initializeLocalVideo();
      }
      if (mounted) {
        SentryDisplayWidget.of(context).reportFullyDisplayed();
      }
    });
  }

  Future<void> _requestPermissions() async {
    if (_requestLock) return;
    _requestLock = true;

    try {
      final statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      final cameraStatus = statuses[Permission.camera]!;
      final micStatus = statuses[Permission.microphone]!;

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
          builder: (BuildContext context) => AlertDialog.adaptive(
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
    if (_videoTrack != null) {
      try {
        await _videoTrack!.stop();
        await _videoTrack!.dispose();
        _videoTrack = null;
      } catch (_) {}
    }
    try {
      _cameraOptions ??= Session.defaultCameraOptions;
      _videoTrack = await LocalVideoTrack.createCameraTrack(_cameraOptions);
      await _videoTrack!.start();
      if (mounted) setState(() {});
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to create local video track',
      );
    }
  }

  void _toggleCamera() {
    setState(() => _isCameraOn = !_isCameraOn);
  }

  void _toggleMic() {
    setState(() => _isMicOn = !_isMicOn);
  }

  bool _joined = false;
  Future<void> _joinRoom(String token) async {
    try {
      await _videoTrack?.stop();
      await _videoTrack?.dispose();
    } catch (_) {}

    if (mounted) {
      context.pushReplacement(
        RouteNames.videoSession(widget.eventSlug),
        extra: VideoRoomScreenRouteArgs(
          cameraOptions: _cameraOptions ?? Session.defaultCameraOptions,
          audioOptions: _audioOptions,
          audioOutputOptions: _audioOutputOptions,
          cameraEnabled: _isCameraOn,
          micEnabled: _isMicOn,
          eventSlug: widget.eventSlug,
          token: token,
        ),
      );
      _joined = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokenData = ref.watch(sessionTokenProvider(widget.eventSlug));

    return tokenData.when(
      data: (token) {
        return PrejoinRoomBaseScreen(
          title: 'Welcome',
          subtitle:
              'Your session will start soon. Please check your audio and video settings before joining.',
          video: Semantics(
            label: 'Your video preview, camera ${_isCameraOn ? 'on' : 'off'}',
            image: true,
            child: LocalParticipantVideoCard(
              isCameraOn: _isCameraOn,
              videoTrack: _videoTrack,
            ),
          ),
          actionBar: ActionBar(
            children: [
              ActionBarButton(
                semanticsLabel: 'Microphone ${_isMicOn ? 'on' : 'off'}',
                onPressed: _toggleMic,
                active: _isMicOn,
                child: TotemIcon(
                  _isMicOn ? TotemIcons.microphoneOn : TotemIcons.microphoneOff,
                ),
              ),
              ActionBarButton(
                semanticsLabel: 'Camera ${_isCameraOn ? 'on' : 'off'}',
                onPressed: _toggleCamera,
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
                      setState(() {
                        _audioOptions = options;
                      });
                    },
                    onAudioOutputChanged: (options) {
                      setState(() {
                        _audioOutputOptions = options;
                      });
                    },
                  );
                },
                child: const Center(
                  child: TotemIcon(TotemIcons.more, size: 18),
                ),
              ),
              SizedBox(
                width: 96,
                child: ActionBarButton(
                  semanticsLabel: 'Join session',
                  onPressed: () => _joinRoom(token),
                  square: false,
                  child: const Text('Join'),
                ),
              ),
            ],
          ),
        );
      },
      error: (error, stackTrace) {
        return RoomBackground(
          child: RoomErrorScreen(
            onRetry: () =>
                ref.refresh(sessionTokenProvider(widget.eventSlug).future),
          ),
        );
      },
      loading: LoadingRoomScreen.new,
    );
  }
}
