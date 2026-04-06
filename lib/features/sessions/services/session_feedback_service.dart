import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/shared/assets.dart';
import 'package:totem_app/shared/logger.dart';

final sessionFeedbackServiceProvider = Provider<SessionFeedbackService>((ref) {
  final service = SessionFeedbackService();
  ref.onDispose(service.dispose);
  return service;
});

class SessionFeedbackService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _configured = false;

  Future<void> playSessionTransitionCue() {
    return _playAsset(TotemAudioAssets.enterLeaveSessionRingtone);
  }

  Future<void> playTotemArrivedCue() {
    return _playAsset(TotemAudioAssets.totemReceivedRingtone);
  }

  Future<void> pulseSwipeCompletion() async {
    await HapticFeedback.lightImpact();
  }

  Future<void> _playAsset(String assetPath) async {
    try {
      await _configurePlayer();
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(_toAssetSourcePath(assetPath)));
    } catch (error, stackTrace) {
      logger.e(
        'Failed to play session feedback sound: $assetPath',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _configurePlayer() async {
    if (_configured) return;

    await _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    await _audioPlayer.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
        android: AudioContextAndroid(
          usageType: AndroidUsageType.notification,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.none,
        ),
      ),
    );

    _configured = true;
  }

  String _toAssetSourcePath(String assetPath) {
    const rootPrefix = 'assets/';
    if (assetPath.startsWith(rootPrefix)) {
      return assetPath.substring(rootPrefix.length);
    }
    return assetPath;
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
