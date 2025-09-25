import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/widgets/action_bar.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

class PreJoinScreen extends ConsumerStatefulWidget {
  const PreJoinScreen({required this.event, super.key});

  final EventDetailSchema event;

  @override
  ConsumerState<PreJoinScreen> createState() => _PreJoinScreenState();
}

class _PreJoinScreenState extends ConsumerState<PreJoinScreen> {
  LocalVideoTrack? _videoTrack;
  var _isCameraOn = true;
  var _isMicOn = true;

  @override
  void initState() {
    super.initState();
    _initializeLocalVideo();
  }

  Future<void> _initializeLocalVideo() async {
    try {
      _videoTrack = await LocalVideoTrack.createCameraTrack();
      await _videoTrack!.start();
      setState(() {});
    } catch (e) {
      debugPrint('Failed to create video track: $e');
    }
  }

  @override
  void dispose() {
    _videoTrack?.stop();
    _videoTrack?.dispose();
    super.dispose();
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOn = !_isCameraOn;
    });
  }

  void _toggleMic() {
    setState(() {
      _isMicOn = !_isMicOn;
    });
  }

  Future<void> _joinRoom() async {
    await _videoTrack?.stop();
    await _videoTrack?.dispose();
    // TODO(bdlukaa): Push RoomScreen with options when available

    // Re-initialize the local video track when returning to this screen
    await _initializeLocalVideo();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);

    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: Container(
            margin: const EdgeInsetsDirectional.only(start: 20),
            alignment: Alignment.center,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.adaptive.arrow_back, color: Colors.black),
                iconSize: 24,
                visualDensity: VisualDensity.compact,
                onPressed: () => popOrHome(context),
              ),
            ),
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
                        color: Colors.white.withValues(alpha: 0.8),
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
                            ..onTap = () {
                              launchUrl(AppConfig.communityGuidelinesUrl);
                            },
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsetsDirectional.symmetric(
                      horizontal: 40,
                      vertical: 10,
                    ),
                    alignment: Alignment.center,
                    // DecoratedBox is overlapping the border
                    // ignore: use_decorated_box
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      clipBehavior: Clip.antiAliasWithSaveLayer,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: AspectRatio(
                          aspectRatio: 16 / 21,
                          child: Builder(
                            builder: (context) {
                              if (_videoTrack == null) {
                                return const LoadingIndicator();
                              } else if (!_isCameraOn) {
                                return Container(
                                  decoration: BoxDecoration(
                                    image: auth.user?.profileImage != null
                                        ? DecorationImage(
                                            image: NetworkImage(
                                              auth.user!.profileImage!,
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  alignment: AlignmentDirectional.bottomCenter,
                                  padding: const EdgeInsets.all(20),
                                  child: AutoSizeText(
                                    auth.user?.name ?? 'You',
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          shadows: kElevationToShadow[6],
                                        ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                  ),
                                );
                              }
                              return VideoTrackRenderer(
                                _videoTrack!,
                                fit: VideoViewFit.cover,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ActionBar(
                  children: [
                    ActionBarButton(
                      onPressed: _toggleMic,
                      active: _isMicOn,
                      child: TotemIcon(
                        _isMicOn
                            ? TotemIcons.microphoneOn
                            : TotemIcons.microphoneOff,
                      ),
                    ),
                    ActionBarButton(
                      onPressed: _toggleCamera,
                      active: _isCameraOn,
                      child: TotemIcon(
                        _isCameraOn
                            ? TotemIcons.cameraOn
                            : TotemIcons.cameraOff,
                      ),
                    ),
                    SizedBox(
                      width: 96,
                      child: ActionBarButton(
                        onPressed: _joinRoom,
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
    );
  }

  Widget buildActionBarButton(Widget child, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        decoration: BoxDecoration(
          color: AppTheme.mauve,
          // shape: BoxShape.circle,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white),
        ),
        child: Center(child: child),
      ),
    );
  }
}
