import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, logger;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/media/livekit_participant_video.dart';

import '../livekit_mocks.dart';

void main() {
  late VoidCallback restoreWebRtcChannels;

  setUpAll(() {
    restoreWebRtcChannels = stubFlutterWebRtcChannels();
  });

  tearDownAll(() {
    restoreWebRtcChannels();
  });

  Future<void> pumpVideo(WidgetTester tester, Participant participant) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LiveKitParticipantVideo(participant: participant)),
      ),
    );
  }

  group('LiveKitParticipantVideo', () {
    testWidgets('keeps a camera renderer mounted across mute transitions', (
      tester,
    ) async {
      final mockParticipant = MockRemoteParticipant('user-2', 'John Doe');
      final mockPublication = MockRemoteTrackPublication<RemoteVideoTrack>();
      final mockTrack = MockRemoteVideoTrack();
      final mutedEvent = MockTrackMutedEvent();
      final unmutedEvent = MockTrackUnmutedEvent();

      when(
        () => mockParticipant.getTrackPublicationBySource(TrackSource.camera),
      ).thenReturn(mockPublication);
      when(() => mockPublication.track).thenReturn(mockTrack);
      when(() => mockPublication.source).thenReturn(TrackSource.camera);
      when(() => mockPublication.sid).thenReturn('pub-sid');
      when(() => mockPublication.subscribed).thenReturn(true);
      when(() => mockPublication.muted).thenReturn(false);
      when(() => mockTrack.sid).thenReturn('track-sid');
      when(() => mockTrack.isActive).thenReturn(true);
      when(() => mockTrack.muted).thenReturn(false);
      when(() => mutedEvent.publication).thenReturn(mockPublication);
      when(() => unmutedEvent.publication).thenReturn(mockPublication);
      await pumpVideo(tester, mockParticipant);
      await tester.pumpAndSettle();

      final renderer = tester.element(find.byType(VideoTrackRenderer));
      check(
        tester.widgetList(find.byType(VideoTrackRenderer)),
      ).length.equals(1);

      for (final event in [
        mutedEvent,
        unmutedEvent,
        mutedEvent,
        unmutedEvent,
      ]) {
        final isMuted = identical(event, mutedEvent);
        when(() => mockPublication.muted).thenReturn(isMuted);
        when(() => mockTrack.muted).thenReturn(isMuted);
        if (isMuted) {
          mockParticipant.listener.emitMuted(event as TrackMutedEvent);
        } else {
          mockParticipant.listener.emitUnmuted(event as TrackUnmutedEvent);
        }
        await tester.pump();

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
      final firstPublication = MockRemoteTrackPublication<RemoteVideoTrack>();
      final firstTrack = MockRemoteVideoTrack();
      final secondPublication = MockRemoteTrackPublication<RemoteVideoTrack>();
      final secondTrack = MockRemoteVideoTrack();
      RemoteTrackPublication<RemoteVideoTrack>? cameraPublication =
          firstPublication;

      when(
        () => participant.getTrackPublicationBySource(TrackSource.camera),
      ).thenAnswer((_) => cameraPublication);
      for (final entry in [
        (publication: firstPublication, track: firstTrack, sid: 'first'),
        (publication: secondPublication, track: secondTrack, sid: 'second'),
      ]) {
        when(() => entry.publication.track).thenReturn(entry.track);
        when(() => entry.publication.source).thenReturn(TrackSource.camera);
        when(() => entry.publication.sid).thenReturn('pub-${entry.sid}');
        when(() => entry.publication.subscribed).thenReturn(true);
        when(() => entry.publication.muted).thenReturn(false);
        when(() => entry.track.sid).thenReturn('track-${entry.sid}');
        when(() => entry.track.isActive).thenReturn(true);
        when(() => entry.track.muted).thenReturn(false);
      }
      await pumpVideo(tester, participant);
      await tester.pumpAndSettle();
      final firstRenderer = tester.element(find.byType(VideoTrackRenderer));

      cameraPublication = secondPublication;
      participant.listener.emitParticipantEvent(
        TrackSubscribedEvent(
          participant: participant,
          publication: secondPublication,
          track: secondTrack,
        ),
      );
      await tester.pumpAndSettle();

      check(
        tester.widgetList(find.byType(VideoTrackRenderer)),
      ).length.equals(1);
      check(
        tester.element(find.byType(VideoTrackRenderer)),
      ).not((it) => it.identicalTo(firstRenderer));

      cameraPublication = null;
      participant.listener.emitParticipantEvent(
        TrackUnpublishedEvent(
          participant: participant,
          publication: secondPublication,
        ),
      );
      await tester.pumpAndSettle();

      check(tester.widgetList(find.byType(VideoTrackRenderer))).isEmpty();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets(
      'shows a locally published camera after the initial build',
      (tester) async {
        final participant = MockLocalParticipant();
        final publication = MockLocalTrackPublication();
        final track = MockLocalVideoTrack();
        LocalTrackPublication<LocalVideoTrack>? cameraPublication;

        when(
          () => participant.getTrackPublicationBySource(TrackSource.camera),
        ).thenAnswer((_) => cameraPublication);
        when(() => publication.track).thenReturn(track);
        when(() => publication.source).thenReturn(TrackSource.camera);
        when(() => publication.sid).thenReturn('local-pub-sid');
        when(() => publication.subscribed).thenReturn(true);
        when(() => publication.muted).thenReturn(false);
        when(() => track.sid).thenReturn('local-track-sid');
        when(() => track.isActive).thenReturn(true);
        when(() => track.muted).thenReturn(false);
        await pumpVideo(tester, participant);

        check(tester.widgetList(find.byType(VideoTrackRenderer))).isEmpty();

        cameraPublication = publication;
        participant.listener.emitParticipantEvent(
          LocalTrackPublishedEvent(
            participant: participant,
            publication: publication,
          ),
        );
        await tester.pumpAndSettle();

        check(
          tester.widgetList(find.byType(VideoTrackRenderer)),
        ).length.equals(1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
      experimentalLeakTesting: LeakTesting.settings.withIgnored(
        classes: <String>['RTCVideoRenderer'],
      ),
    );

    testWidgets(
      'shows a camera track subscribed after the initial build',
      (tester) async {
        final participant = MockRemoteParticipant('user-2', 'John Doe');
        final publication = MockRemoteTrackPublication<RemoteVideoTrack>();
        final track = MockRemoteVideoTrack();
        RemoteTrackPublication<RemoteVideoTrack>? cameraPublication;

        when(
          () => participant.getTrackPublicationBySource(TrackSource.camera),
        ).thenAnswer((_) => cameraPublication);
        when(() => publication.track).thenReturn(track);
        when(() => publication.source).thenReturn(TrackSource.camera);
        when(() => publication.sid).thenReturn('pub-sid');
        when(() => publication.subscribed).thenReturn(true);
        when(() => publication.muted).thenReturn(false);
        when(() => track.sid).thenReturn('track-sid');
        when(() => track.isActive).thenReturn(true);
        when(() => track.muted).thenReturn(false);
        await pumpVideo(tester, participant);

        check(tester.widgetList(find.byType(VideoTrackRenderer))).isEmpty();

        cameraPublication = publication;
        participant.listener.emitParticipantEvent(
          TrackSubscribedEvent(
            participant: participant,
            publication: publication,
            track: track,
          ),
        );
        await tester.pumpAndSettle();

        check(
          tester.widgetList(find.byType(VideoTrackRenderer)),
        ).length.equals(1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
      experimentalLeakTesting: LeakTesting.settings.withIgnored(
        classes: <String>['RTCVideoRenderer'],
      ),
    );
  });
}
