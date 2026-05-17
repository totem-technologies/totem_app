import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/shared/assets.dart';
import 'package:totem_core/shared/logger.dart';

final sessionCuesServiceProvider = Provider<SessionCuesService>((ref) {
  final service = SessionCuesService();
  ref.onDispose(service.dispose);
  return service;
});

typedef SessionCuesHapticPulseCallback = Future<void> Function();

abstract class SessionCuesAudioPlayer {
  Future<void> setPlayerMode(PlayerMode mode);
  Future<void> setReleaseMode(ReleaseMode mode);
  Future<void> setAudioContext(AudioContext context);
  Future<void> stop();
  Future<void> playAsset(String assetSourcePath);
  void dispose();
}

// For now, we disabled audio player.
class _UselessAudioPlayer implements SessionCuesAudioPlayer {
  @override
  Future<void> setAudioContext(AudioContext context) async {}

  @override
  Future<void> setPlayerMode(PlayerMode mode) async {}

  @override
  Future<void> setReleaseMode(ReleaseMode mode) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> playAsset(String assetSourcePath) async {}

  @override
  void dispose() {}
}

// class AudioplayersSessionCuesAudioPlayer implements SessionCuesAudioPlayer {
//   AudioplayersSessionCuesAudioPlayer() : _player = AudioPlayer();

//   final AudioPlayer _player;

//   @override
//   Future<void> setPlayerMode(PlayerMode mode) => _player.setPlayerMode(mode);

//   @override
//   Future<void> setReleaseMode(ReleaseMode mode) => _player.setReleaseMode(mode);

//   @override
//   Future<void> setAudioContext(AudioContext context) =>
//       _player.setAudioContext(context);

//   @override
//   Future<void> stop() => _player.stop();

//   @override
//   Future<void> playAsset(String assetSourcePath) {
//     return _player.play(AssetSource(assetSourcePath), volume: 0.5);
//   }

//   @override
//   void dispose() {
//     _player.dispose();
//   }
// }

class SessionCuesService {
  SessionCuesService({
    SessionCuesAudioPlayer? audioPlayer,
    SessionCuesHapticPulseCallback? pulseHaptic,
  }) : _pulseHaptic = pulseHaptic ?? defaultHapticPulse,
       _audioPlayer = audioPlayer;

  static Future<void> defaultHapticPulse() {
    // https://github.com/flutter/flutter/issues/157442
    if (kIsWeb) {
      return HapticFeedback.lightImpact();
    }

    return HapticFeedback.heavyImpact();
  }

  SessionCuesAudioPlayer? _audioPlayer;
  final SessionCuesHapticPulseCallback _pulseHaptic;
  bool _configured = false;
  Timer? _transitionCueDelayTimer;

  Future<void> playSessionTransitionCue() async {
    // Adding a delay before playing the session cue to ensure
    // the audio plays isn't interfered with by any audio changes
    //that may occur during session transitions.
    _transitionCueDelayTimer?.cancel();
    final completer = Completer<void>();
    _transitionCueDelayTimer = Timer(const Duration(milliseconds: 1500), () {
      _transitionCueDelayTimer = null;
      _playAsset(TotemAudioAssets.enterLeaveSessionRingtone).whenComplete(() {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
    });
    return completer.future;
  }

  Future<void> playTotemReceivedCue() {
    return _playAsset(TotemAudioAssets.totemReceivedRingtone);
  }

  Future<void> pulseSwipeCompletion() async {
    try {
      await _pulseHaptic();
    } catch (error, stackTrace) {
      logger.e('Failed to pulse haptic', error: error, stackTrace: stackTrace);
    }
  }

  bool _isPlaying = false;

  Future<void> _playAsset(String assetPath) async {
    if (_isPlaying) return;

    try {
      await _configurePlayer();
      await _audioPlayer?.stop();
      _isPlaying = true;
      await _audioPlayer?.playAsset(_toAssetSourcePath(assetPath));
    } catch (error, stackTrace) {
      logger.e(
        'Failed to play session feedback sound: $assetPath',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _isPlaying = false;
    }
  }

  Future<void> _configurePlayer() async {
    if (_configured) return;

    AudioCache.instance = AudioCache(prefix: 'packages/totem_core/assets/');
    _audioPlayer ??= _UselessAudioPlayer();

    await _audioPlayer?.setPlayerMode(PlayerMode.lowLatency);
    await _audioPlayer?.setReleaseMode(ReleaseMode.stop);

    // Set audio context to preserve existing audio routing (speaker/headphones state)
    // during session join/leave transitions.
    if (!kIsWeb) {
      await _audioPlayer?.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.gainTransient,
          ),
        ),
      );
    }

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
    _transitionCueDelayTimer?.cancel();
    _transitionCueDelayTimer = null;
    _audioPlayer?.dispose();
  }
}
