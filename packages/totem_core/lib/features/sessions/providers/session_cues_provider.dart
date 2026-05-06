import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/shared/assets.dart';
import 'package:totem_app/shared/logger.dart';

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

class AudioplayersSessionCuesAudioPlayer implements SessionCuesAudioPlayer {
  AudioplayersSessionCuesAudioPlayer() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> setPlayerMode(PlayerMode mode) => _player.setPlayerMode(mode);

  @override
  Future<void> setReleaseMode(ReleaseMode mode) => _player.setReleaseMode(mode);

  @override
  Future<void> setAudioContext(AudioContext context) =>
      _player.setAudioContext(context);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> playAsset(String assetSourcePath) {
    return _player.play(AssetSource(assetSourcePath), volume: 0.5);
  }

  @override
  void dispose() {
    _player.dispose();
  }
}

class SessionCuesService {
  SessionCuesService({
    SessionCuesAudioPlayer? audioPlayer,
    SessionCuesHapticPulseCallback? pulseHaptic,
  }) : _audioPlayer = audioPlayer ?? AudioplayersSessionCuesAudioPlayer(),
       _pulseHaptic = pulseHaptic ?? defaultHapticPulse;

  static Future<void> defaultHapticPulse() {
    // https://github.com/flutter/flutter/issues/157442
    if (kIsWeb) {
      return HapticFeedback.lightImpact();
    }
    if (Platform.isIOS) {
      return HapticFeedback.vibrate();
    }

    return HapticFeedback.lightImpact();
  }

  final SessionCuesAudioPlayer _audioPlayer;
  final SessionCuesHapticPulseCallback _pulseHaptic;
  bool _configured = false;

  Future<void> playSessionTransitionCue() {
    return _playAsset(TotemAudioAssets.enterLeaveSessionRingtone);
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
      await _audioPlayer.stop();
      _isPlaying = true;
      await _audioPlayer.playAsset(_toAssetSourcePath(assetPath));
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

    await _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    await _audioPlayer.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playAndRecord,
          options: const {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.media,
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
