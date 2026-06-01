import 'package:flutter_test/flutter_test.dart';

// restore tests after functionality is re-enabled
// class _FakeSessionCuesAudioPlayer implements SessionCuesAudioPlayer {
//   final List<PlayerMode> playerModes = <PlayerMode>[];
//   final List<ReleaseMode> releaseModes = <ReleaseMode>[];
//   final List<AudioContext> audioContexts = <AudioContext>[];
//   final List<String> playedAssets = <String>[];

//   int stopCallCount = 0;
//   int disposeCallCount = 0;

//   @override
//   Future<void> setPlayerMode(PlayerMode mode) async {
//     playerModes.add(mode);
//   }

//   @override
//   Future<void> setReleaseMode(ReleaseMode mode) async {
//     releaseModes.add(mode);
//   }

//   @override
//   Future<void> setAudioContext(AudioContext context) async {
//     audioContexts.add(context);
//   }

//   @override
//   Future<void> stop() async {
//     stopCallCount += 1;
//   }

//   @override
//   Future<void> playAsset(String assetSourcePath) async {
//     playedAssets.add(assetSourcePath);
//   }

//   @override
//   void dispose() {
//     disposeCallCount += 1;
//   }
// }

void main() {
  group('SessionCuesService', () {
    // test(
    //   'plays transition cue with configured one-shot audio behavior',
    //   () async {
    //     final fakePlayer = _FakeSessionCuesAudioPlayer();
    //     final service = SessionCuesService(audioPlayer: fakePlayer);

    //     await service.playSessionTransitionCue();

    //     expect(fakePlayer.playerModes, [PlayerMode.lowLatency]);
    //     expect(fakePlayer.releaseModes, [ReleaseMode.stop]);
    //     expect(
    //       fakePlayer.audioContexts,
    //       [
    //         AudioContext(
    //           iOS: AudioContextIOS(
    //             category: AVAudioSessionCategory.playback,
    //             options: const {
    //               AVAudioSessionOptions.mixWithOthers,
    //             },
    //           ),
    //           android: const AudioContextAndroid(
    //             audioFocus: AndroidAudioFocus.gainTransient,
    //           ),
    //         ),
    //       ],
    //     );
    //     expect(fakePlayer.stopCallCount, 1);
    //     expect(
    //       fakePlayer.playedAssets,
    //       ['audio/enter_leave_session_ringtone.mp3'],
    //     );
    //   },
    // );

    // test(
    //   'plays totem cue and does not reconfigure player after first play',
    //   () async {
    //     final fakePlayer = _FakeSessionCuesAudioPlayer();
    //     final service = SessionCuesService(audioPlayer: fakePlayer);

    //     await service.playSessionTransitionCue();
    //     await service.playTotemReceivedCue();

    //     expect(fakePlayer.playerModes, [PlayerMode.lowLatency]);
    //     expect(fakePlayer.releaseModes, [ReleaseMode.stop]);
    //     expect(
    //       fakePlayer.audioContexts,
    //       [
    //         AudioContext(
    //           iOS: AudioContextIOS(
    //             category: AVAudioSessionCategory.playback,
    //             options: const {
    //               AVAudioSessionOptions.mixWithOthers,
    //             },
    //           ),
    //           android: const AudioContextAndroid(
    //             audioFocus: AndroidAudioFocus.gainTransient,
    //           ),
    //         ),
    //       ],
    //     );
    //     expect(fakePlayer.stopCallCount, 2);
    //     expect(
    //       fakePlayer.playedAssets,
    //       [
    //         'audio/enter_leave_session_ringtone.mp3',
    //         'audio/totem_received_ringtone.mp3',
    //       ],
    //     );
    //   },
    // );

    // test('fires light haptic pulse callback on swipe completion', () async {
    //   var pulseCount = 0;
    //   final service = SessionCuesService(
    //     audioPlayer: _FakeSessionCuesAudioPlayer(),
    //     pulseHaptic: () async {
    //       pulseCount += 1;
    //     },
    //   );

    //   await service.pulseSwipeCompletion();

    //   expect(pulseCount, 1);
    // });

    // test('disposes underlying audio player', () {
    //   final fakePlayer = _FakeSessionCuesAudioPlayer();
    //   final _ = SessionCuesService(audioPlayer: fakePlayer)..dispose();

    //   expect(fakePlayer.disposeCallCount, 1);
    // });
  });
}
