import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, logger;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/media/livekit_participant_video.dart';

import '../livekit_mocks.dart';

typedef _Camera = ({
  MockRemoteTrackPublication<RemoteVideoTrack> publication,
  MockRemoteVideoTrack track,
});

_Camera _camera(String sid) {
  final publication = MockRemoteTrackPublication<RemoteVideoTrack>();
  final track = MockRemoteVideoTrack();
  when(() => publication.track).thenReturn(track);
  when(() => publication.source).thenReturn(TrackSource.camera);
  when(() => publication.sid).thenReturn('pub-$sid');
  when(() => publication.subscribed).thenReturn(true);
  when(() => publication.muted).thenReturn(false);
  when(() => track.sid).thenReturn('track-$sid');
  when(() => track.isActive).thenReturn(true);
  when(() => track.muted).thenReturn(false);
  return (publication: publication, track: track);
}

void main() {
  late VoidCallback restoreWebRtcChannels;
  late StreamController<void> changes;

  setUpAll(() {
    restoreWebRtcChannels = stubFlutterWebRtcChannels();
  });

  tearDownAll(() {
    restoreWebRtcChannels();
  });

  setUp(() => changes = StreamController<void>.broadcast(sync: true));
  tearDown(() => changes.close());

  Future<void> pumpVideo(
    WidgetTester tester,
    Participant? Function() participant,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveKitParticipantVideo(
            participant: participant,
            changes: changes.stream,
          ),
        ),
      ),
    );
  }

  Future<void> change(WidgetTester tester) async {
    changes.add(null);
    await tester.pumpAndSettle();
  }

  final ignoreRenderers = LeakTesting.settings.withIgnored(
    classes: <String>['RTCVideoRenderer'],
  );

  group('LiveKitParticipantVideo', () {
    testWidgets('keeps a camera renderer mounted across mute transitions', (
      tester,
    ) async {
      final participant = MockRemoteParticipant('user-2', 'John Doe');
      final camera = _camera('1');
      when(
        () => participant.getTrackPublicationBySource(TrackSource.camera),
      ).thenReturn(camera.publication);
      await pumpVideo(tester, () => participant);
      await tester.pumpAndSettle();

      final renderer = tester.element(find.byType(VideoTrackRenderer));

      for (final muted in [true, false, true, false]) {
        when(() => camera.publication.muted).thenReturn(muted);
        when(() => camera.track.muted).thenReturn(muted);
        await change(tester);

        check(
          tester.element(find.byType(VideoTrackRenderer)),
        ).identicalTo(renderer);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('replaces or removes the renderer when the track changes', (
      tester,
    ) async {
      final participant = MockRemoteParticipant('user-2', 'John Doe');
      final first = _camera('first');
      final second = _camera('second');
      RemoteTrackPublication<RemoteVideoTrack>? cameraPublication =
          first.publication;
      when(
        () => participant.getTrackPublicationBySource(TrackSource.camera),
      ).thenAnswer((_) => cameraPublication);
      await pumpVideo(tester, () => participant);
      await tester.pumpAndSettle();
      final firstRenderer = tester.element(find.byType(VideoTrackRenderer));

      cameraPublication = second.publication;
      await change(tester);

      check(
        tester.widgetList(find.byType(VideoTrackRenderer)),
      ).length.equals(1);
      check(
        tester.element(find.byType(VideoTrackRenderer)),
      ).not((it) => it.identicalTo(firstRenderer));

      cameraPublication = null;
      await change(tester);

      check(tester.widgetList(find.byType(VideoTrackRenderer))).isEmpty();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets(
      'shows a camera that becomes available after the initial build',
      (tester) async {
        final participant = MockRemoteParticipant('user-2', 'John Doe');
        final camera = _camera('1');
        RemoteTrackPublication<RemoteVideoTrack>? cameraPublication;
        when(
          () => participant.getTrackPublicationBySource(TrackSource.camera),
        ).thenAnswer((_) => cameraPublication);
        await pumpVideo(tester, () => participant);

        check(tester.widgetList(find.byType(VideoTrackRenderer))).isEmpty();

        cameraPublication = camera.publication;
        await change(tester);

        check(
          tester.widgetList(find.byType(VideoTrackRenderer)),
        ).length.equals(1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
      experimentalLeakTesting: ignoreRenderers,
    );

    testWidgets('follows a participant who leaves and rejoins', (tester) async {
      final before = MockRemoteParticipant('user-2', 'John Doe');
      final after = MockRemoteParticipant('user-2', 'John Doe');
      final camera = _camera('before');
      final rejoinedCamera = _camera('after');
      when(
        () => before.getTrackPublicationBySource(TrackSource.camera),
      ).thenReturn(camera.publication);
      when(
        () => after.getTrackPublicationBySource(TrackSource.camera),
      ).thenReturn(rejoinedCamera.publication);
      Participant? current = before;
      await pumpVideo(tester, () => current);
      await tester.pumpAndSettle();

      current = null;
      await change(tester);
      check(tester.widgetList(find.byType(VideoTrackRenderer))).isEmpty();

      current = after;
      await change(tester);
      final key = tester.widget(find.byType(VideoTrackRenderer)).key;
      check((key! as ValueKey).value).equals(('pub-after', 'track-after'));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, experimentalLeakTesting: ignoreRenderers);
  });
}
