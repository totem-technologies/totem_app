import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/controllers/core/join_media_owner.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';

import '../../../../setup.dart';
import '../../livekit_mocks.dart';

void main() {
  setupAppConfig();
  silenceLogger();

  for (final accepted in [true, false]) {
    test(
      'cleanup waits for publication; adapter accepts tracks: $accepted',
      () async {
        final owner = JoinMediaOwner();
        final camera = MockLocalVideoTrack();
        final microphone = MockLocalAudioTrack();
        var detached = false;
        final media = SessionJoinMedia(
          cameraTrack: camera,
          microphoneTrack: microphone,
          onBeforeDispose: () => detached = true,
        );
        when(camera.stop).thenAnswer((_) async {
          check(detached).isTrue();
          return true;
        });
        final receipt = owner.retain(media);
        final publication = Completer<bool>();
        final publishing = owner.publish(camera, () => publication.future);
        var cleaned = false;
        final cleanup = owner.disposeAll().then((_) => cleaned = true);
        await Future<void>.value();
        check(cleaned).isFalse();
        verifyNever(camera.stop);
        verifyNever(microphone.stop);
        publication.complete(accepted);
        check(await publishing).equals(accepted);
        await cleanup;
        await receipt.dispose();
        await owner.disposeAll();
        if (accepted) {
          verifyNever(camera.stop);
          verifyNever(camera.dispose);
        } else {
          verify(camera.stop).called(1);
          verify(camera.dispose).called(1);
        }
        verify(microphone.stop).called(1);
        verify(microphone.dispose).called(1);
        check(detached).isTrue();
        // Repeated commands cannot reclaim either accepted or disposed tracks.
        await owner.retain(media).dispose();
        verifyNoMoreInteractions(camera);
        verifyNoMoreInteractions(microphone);
      },
    );
  }

  test(
    'publication exception preserves preview-detach and exactly-once release',
    () async {
      final owner = JoinMediaOwner();
      final track = MockLocalVideoTrack();
      var detached = false;
      final receipt = owner.retain(
        SessionJoinMedia(
          cameraTrack: track,
          onBeforeDispose: () => detached = true,
        ),
      );
      when(track.stop).thenAnswer((_) async {
        check(detached).isTrue();
        return true;
      });
      await check(
        owner.publish(
          track,
          () async => throw StateError('publication failed'),
        ),
      ).throws<StateError>();
      await Future.wait([receipt.dispose(), owner.disposeAll()]);
      verify(track.stop).called(1);
      verify(track.dispose).called(1);
      check(detached).isTrue();
    },
  );
}
