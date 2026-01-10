import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_app/core/config/app_config.dart';
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
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/circle_icon_button.dart';
import 'package:url_launcher/url_launcher.dart';

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

  var _cameraOptions = const CameraCaptureOptions();
  var _audioOptions = const AudioCaptureOptions();
  var _audioOutputOptions = const AudioOutputOptions();

  @override
  void initState() {
    super.initState();
    _initializeAndCheckPermissions();
  }

  @override
  void dispose() {
    if (_videoTrack != null) {
      _videoTrack!.stop();
      _videoTrack!.dispose();
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
    final cameraGranted = await Permission.camera.request();
    final micGranted = await Permission.microphone.request();
    await BackgroundControl.requestPermissions();

    if (!cameraGranted.isGranted || !micGranted.isGranted) {
      if (!mounted) return;

      // Build permission text based on what's missing
      final missingPermissions = <String>[];
      if (!cameraGranted.isGranted) missingPermissions.add('Camera');
      if (!micGranted.isGranted) missingPermissions.add('Microphone');
      final permissionText = missingPermissions.join(' and ');

      await showAdaptiveDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return AlertDialog.adaptive(
            title: const Text('Permissions Required'),
            content: Text(
              '$permissionText access ${missingPermissions.length == 1 ? 'is' : 'are'} required to join the session. Please grant ${missingPermissions.length == 1 ? 'this permission' : 'these permissions'} in your device settings.',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text(
                  'Exit',
                  style: TextStyle(decoration: TextDecoration.none),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  if (mounted) Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text(
                  'Open Settings',
                  style: TextStyle(decoration: TextDecoration.none),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
              ),
            ],
          );
        },
      );
    }
    _requestLock = false;
  }

  Future<void> _initializeLocalVideo() async {
    if (_videoTrack != null) {
      await _videoTrack!.stop();
      await _videoTrack!.dispose();
    }
    try {
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

  Future<void> _joinRoom(String token) async {
    await _videoTrack?.stop();
    await _videoTrack?.dispose();

    if (mounted) {
      context.pushReplacement(
        RouteNames.videoSession(widget.eventSlug),
        extra: VideoRoomScreenRouteArgs(
          cameraOptions: _cameraOptions,
          audioOptions: _audioOptions,
          audioOutputOptions: _audioOutputOptions,
          cameraEnabled: _isCameraOn,
          micEnabled: _isMicOn,
          eventSlug: widget.eventSlug,
          token: token,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokenData = ref.watch(sessionTokenProvider(widget.eventSlug));

    return tokenData.when(
      data: (token) => Scaffold(
        appBar: AppBar(
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: CircleIconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            margin: const EdgeInsetsDirectional.only(start: 20),
            icon: TotemIcons.arrowBack,
            onPressed: () => popOrHome(context),
          ),
        ),
        extendBodyBehindAppBar: true,
        body: RoomBackground(
          padding: const EdgeInsetsDirectional.all(20),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Welcome to this Space',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 20,
                  ),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.8,
                        ),
                      ),
                      children: [
                        const TextSpan(
                          text:
                              'It will start soon. '
                              'Verify your audio and video settings before '
                              'joining.\n'
                              '\n'
                              'Please take a moment to go over the',
                        ),
                        TextSpan(
                          text: '\ncommunity guidelines',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () =>
                                launchUrl(AppConfig.communityGuidelinesUrl),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 40,
                      vertical: 10,
                    ),
                    child: Semantics(
                      label:
                          'Your video preview, camera ${_isCameraOn ? 'on' : 'off'}',
                      image: true,
                      child: RepaintBoundary(
                        child: LocalParticipantVideoCard(
                          isCameraOn: _isCameraOn,
                          videoTrack: _videoTrack,
                        ),
                      ),
                    ),
                  ),
                ),
                ActionBar(
                  children: [
                    ActionBarButton(
                      semanticsLabel: 'Microphone ${_isMicOn ? 'on' : 'off'}',
                      onPressed: _toggleMic,
                      active: _isMicOn,
                      child: TotemIcon(
                        _isMicOn
                            ? TotemIcons.microphoneOn
                            : TotemIcons.microphoneOff,
                      ),
                    ),
                    ActionBarButton(
                      semanticsLabel: 'Camera ${_isCameraOn ? 'on' : 'off'}',
                      onPressed: _toggleCamera,
                      active: _isCameraOn,
                      child: TotemIcon(
                        _isCameraOn
                            ? TotemIcons.cameraOn
                            : TotemIcons.cameraOff,
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
              ],
            ),
          ),
        ),
      ),
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
