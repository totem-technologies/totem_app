import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class PreJoinScreen extends StatefulWidget {
  const PreJoinScreen({super.key});

  @override
  State<PreJoinScreen> createState() => _PreJoinScreenState();
}

class _PreJoinScreenState extends State<PreJoinScreen> {
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
      _videoTrack?.mute(stopOnMute: !_isCameraOn);
    });
  }

  void _toggleMic() {
    setState(() {
      _isMicOn = !_isMicOn;
    });
  }

  void _joinRoom() {
    // Navigator.of(context).push(
    //   MaterialPageRoute(
    //     builder: (context) => VideoRoomScreen(
    //       roomName: widget.roomName,
    //       token: widget.token,
    //       cameraEnabled: _isCameraOn,
    //       micEnabled: _isMicOn,
    //     ),
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to this space'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'It will start soon. '
            'Verify your audio and video settings before joining.\n'
            '\n'
            'Please take a moment to go over the community guidelines.',
          ),
          Expanded(
            child: _videoTrack != null
                ? VideoTrackRenderer(_videoTrack!)
                : const Center(child: CircularProgressIndicator()),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(_isMicOn ? Icons.mic : Icons.mic_off),
                  onPressed: _toggleMic,
                ),
                IconButton(
                  icon: Icon(_isCameraOn ? Icons.videocam : Icons.videocam_off),
                  onPressed: _toggleCamera,
                ),
                ElevatedButton(
                  onPressed: _joinRoom,
                  child: const Text('Join Room'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
