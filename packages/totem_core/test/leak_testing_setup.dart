import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

void configureTotemLeakTesting() {
  LeakTesting.enable();
  LeakTesting.settings = LeakTesting.settings
      .withIgnored(createdByTestHelpers: true)
      .withIgnored(
        classes: <String>[
          'AudioTrack',
          'VideoTrack',
          'LocalAudioTrack',
          'LocalVideoTrack',
          'RemoteAudioTrack',
          'RemoteVideoTrack',
          'Participant',
          'LocalParticipant',
          'RemoteParticipant',
          'TrackPublication',
          'LocalTrackPublication',
          'RemoteTrackPublication',
          'Room',
        ],
      );
}
