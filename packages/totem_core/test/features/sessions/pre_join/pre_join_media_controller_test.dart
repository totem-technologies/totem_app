import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_media_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';

import '../../../setup.dart';
import '../livekit_mocks.dart';

const _sessionSlug = 'pre-join-media-test';

class _PreviewTrackFactory extends PreJoinPreviewTrackFactory {
  final videoTracks = <MockPreJoinLocalVideoTrack>[];
  final audioTracks = <MockPreJoinLocalAudioTrack>[];

  @override
  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions cameraOptions,
  ) async {
    final track = MockPreJoinLocalVideoTrack();
    videoTracks.add(track);
    return track;
  }

  @override
  Future<LocalAudioTrack?> createAudioTrack() async {
    final track = MockPreJoinLocalAudioTrack();
    audioTracks.add(track);
    return track;
  }
}

class _DelayedCameraFactory extends _PreviewTrackFactory {
  final gate = Completer<void>();
  bool cameraRequested = false;

  @override
  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions cameraOptions,
  ) async {
    cameraRequested = true;
    await gate.future;
    return await super.createVideoTrack(cameraOptions);
  }
}

class _DelayedMicrophoneFactory extends _PreviewTrackFactory {
  final gate = Completer<void>();
  bool microphoneRequested = false;

  @override
  Future<LocalAudioTrack?> createAudioTrack() async {
    microphoneRequested = true;
    await gate.future;
    return await super.createAudioTrack();
  }
}

class _UnavailableCameraFactory extends _PreviewTrackFactory {
  @override
  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions cameraOptions,
  ) => throw Exception('NotFoundError: no camera is available');
}

class _PermissionDeniedCameraFactory extends _PreviewTrackFactory {
  @override
  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions cameraOptions,
  ) => throw TrackCreateException('NotAllowedError: permission denied');
}

class _ThrowingInitializationController extends PreJoinMediaController {
  @override
  Future<void> initialize() async {
    throw StateError('unexpected initialization failure');
  }
}

Future<PreJoinMediaState> _waitUntilInitialized(
  ProviderContainer container,
) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    final state = container.read(preJoinMediaControllerProvider(_sessionSlug));
    if (state.initializationComplete) return state;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('Pre-join media did not initialize');
}

ProviderContainer _createContainer(
  PreJoinPreviewTrackFactory factory, {
  PreJoinMediaController Function()? controller,
}) {
  return ProviderContainer(
    overrides: [
      preJoinPreviewTrackFactoryProvider.overrideWithValue(factory),
      if (controller != null)
        preJoinMediaControllerProvider(_sessionSlug).overrideWith(controller),
    ],
  )..listen(
    preJoinMediaControllerProvider(_sessionSlug),
    (_, _) {},
    fireImmediately: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setupAppConfig);

  test('operation queue continues after a failed operation', () async {
    final queue = PreJoinMediaOperationQueue();
    final failed = queue.schedule<void>(
      () async => throw StateError('capture failed'),
    );

    await check(failed).throws<StateError>();
    check(queue.pending).isNotNull();
    await check(queue.pending!).completes();
    check(await queue.schedule(() async => 42)).equals(42);
  });

  test('failed initial future does not poison media retry', () async {
    final factory = _PreviewTrackFactory();
    final container = _createContainer(
      factory,
      controller: _ThrowingInitializationController.new,
    );
    addTearDown(container.dispose);

    final failedState = await _waitUntilInitialized(container);
    check(failedState.camera.phase).equals(PreJoinCapturePhase.unavailable);
    check(failedState.microphone.phase).equals(PreJoinCapturePhase.unavailable);

    final recoveredState = await container
        .read(preJoinMediaControllerProvider(_sessionSlug).notifier)
        .retryFailedMedia();

    check(recoveredState.camera.isReady).equals(true);
    check(recoveredState.microphone.isReady).equals(true);
  });

  test('camera unavailable still allows a microphone-only web join', () async {
    final factory = _UnavailableCameraFactory();
    final container = _createContainer(factory);
    addTearDown(container.dispose);

    final state = await _waitUntilInitialized(container);
    check(state.camera.phase).equals(PreJoinCapturePhase.unavailable);
    check(state.microphone.phase).equals(PreJoinCapturePhase.ready);
    check(state.canJoinOnWeb).equals(true);

    final media = await container
        .read(preJoinMediaControllerProvider(_sessionSlug).notifier)
        .takeForJoin();
    check(media.cameraTrack).isNull();
    check(media.microphoneTrack).identicalTo(factory.audioTracks.single);
  });

  test('explicit camera permission denial blocks a web join', () async {
    final state = PreJoinMediaState(
      camera: PreJoinCaptureState<LocalVideoTrack>(
        phase: PreJoinCapturePhase.permissionDenied,
        error: Exception('NotAllowedError: permission denied'),
      ),
      microphone: PreJoinCaptureState<LocalAudioTrack>(
        phase: PreJoinCapturePhase.ready,
        track: MockLocalAudioTrack(),
      ),
    );
    check(state.canJoinOnWeb).equals(false);
  });

  test('typed track creation permission errors are classified', () async {
    final container = _createContainer(_PermissionDeniedCameraFactory());
    addTearDown(container.dispose);

    final state = await _waitUntilInitialized(container);

    check(state.camera.phase).equals(PreJoinCapturePhase.permissionDenied);
    check(state.canJoinOnWeb).equals(false);
  });

  test(
    'camera permission revocation invalidates ready preview media',
    () async {
      final factory = _PreviewTrackFactory();
      final container = _createContainer(factory);
      addTearDown(container.dispose);
      await _waitUntilInitialized(container);

      factory.videoTracks.single.mockMediaStreamTrack.onEnded?.call();

      final state = container.read(
        preJoinMediaControllerProvider(_sessionSlug),
      );
      check(state.camera.phase).equals(PreJoinCapturePhase.permissionDenied);
      check(state.camera.track).isNull();
      check(state.canJoinOnWeb).equals(false);
      await check(
        container
            .read(preJoinMediaControllerProvider(_sessionSlug).notifier)
            .takeForJoin(requireUsableMedia: true),
      ).throws<PreJoinMediaPermissionDeniedException>();
    },
  );

  test(
    'microphone permission revocation invalidates ready preview media',
    () async {
      final factory = _PreviewTrackFactory();
      final container = _createContainer(factory);
      addTearDown(container.dispose);
      await _waitUntilInitialized(container);

      factory.audioTracks.single.mockMediaStreamTrack.onEnded?.call();

      final state = container.read(
        preJoinMediaControllerProvider(_sessionSlug),
      );
      check(
        state.microphone.phase,
      ).equals(PreJoinCapturePhase.permissionDenied);
      check(state.microphone.track).isNull();
      check(state.canJoinOnWeb).equals(false);
    },
  );

  test('camera and microphone capture are initialized sequentially', () async {
    final factory = _DelayedCameraFactory();
    final container = _createContainer(factory);
    addTearDown(container.dispose);
    await Future<void>.delayed(Duration.zero);

    check(factory.cameraRequested).equals(true);
    check(factory.audioTracks).isEmpty();
    factory.gate.complete();
    await _waitUntilInitialized(container);
    check(factory.videoTracks).length.equals(1);
    check(factory.audioTracks).length.equals(1);
  });

  test('microphone disabled during camera capture is never acquired', () async {
    final factory = _DelayedCameraFactory();
    final container = _createContainer(factory);
    addTearDown(container.dispose);
    await Future<void>.delayed(Duration.zero);

    final controller = container.read(
      preJoinMediaControllerProvider(_sessionSlug).notifier,
    );
    final toggle = controller.toggleMicrophone();
    factory.gate.complete();
    await toggle;
    final state = await _waitUntilInitialized(container);

    check(factory.audioTracks).isEmpty();
    check(state.microphone.phase).equals(PreJoinCapturePhase.disabled);
  });

  test('microphone toggles share the in-flight camera capture queue', () async {
    final factory = _DelayedCameraFactory();
    final container = _createContainer(factory);
    addTearDown(container.dispose);
    await Future<void>.delayed(Duration.zero);

    final controller = container.read(
      preJoinMediaControllerProvider(_sessionSlug).notifier,
    );
    var toggleCompleted = false;
    final toggleOff = controller.toggleMicrophone().whenComplete(
      () => toggleCompleted = true,
    );
    await Future<void>.delayed(Duration.zero);

    check(toggleCompleted).equals(false);
    check(factory.audioTracks).isEmpty();

    factory.gate.complete();
    await toggleOff;
    await controller.toggleMicrophone();
    final state = await _waitUntilInitialized(container);

    check(factory.videoTracks).length.equals(1);
    check(factory.audioTracks).length.equals(1);
    check(state.microphone.isReady).equals(true);
  });

  test('microphone stop waits for in-flight initialization', () async {
    final factory = _DelayedMicrophoneFactory();
    final container = _createContainer(factory);
    addTearDown(container.dispose);
    for (
      var attempt = 0;
      attempt < 20 && !factory.microphoneRequested;
      attempt++
    ) {
      await Future<void>.delayed(Duration.zero);
    }

    final controller = container.read(
      preJoinMediaControllerProvider(_sessionSlug).notifier,
    );
    final toggle = controller.toggleMicrophone();
    factory.gate.complete();
    await toggle;

    final track = factory.audioTracks.single;
    verify(track.stop).called(1);
    verify(track.dispose).called(1);
    check(
      container
          .read(preJoinMediaControllerProvider(_sessionSlug))
          .microphone
          .phase,
    ).equals(PreJoinCapturePhase.disabled);
  });

  test(
    'transfer reuses tracks and provider disposal does not stop them',
    () async {
      final factory = _PreviewTrackFactory();
      final container = _createContainer(factory);
      await _waitUntilInitialized(container);
      final media = await container
          .read(preJoinMediaControllerProvider(_sessionSlug).notifier)
          .takeForJoin();

      check(media.cameraTrack).identicalTo(factory.videoTracks.single);
      check(media.microphoneTrack).identicalTo(factory.audioTracks.single);
      container.dispose();
      await Future<void>.delayed(Duration.zero);
      verifyNever(factory.videoTracks.single.stop);
      verifyNever(factory.videoTracks.single.dispose);
      verifyNever(factory.audioTracks.single.stop);
      verifyNever(factory.audioTracks.single.dispose);
    },
  );

  test(
    'detaching transferred tracks clears render state synchronously',
    () async {
      final factory = _PreviewTrackFactory();
      final container = _createContainer(factory);
      await _waitUntilInitialized(container);
      final controller = container.read(
        preJoinMediaControllerProvider(_sessionSlug).notifier,
      );
      final media = await controller.takeForJoin();

      controller.detachTransferredTracks();

      final detached = container.read(
        preJoinMediaControllerProvider(_sessionSlug),
      );
      check(detached.transferred).equals(true);
      check(detached.camera.track).isNull();
      check(detached.camera.phase).equals(PreJoinCapturePhase.uninitialized);
      check(detached.microphone.track).isNull();
      check(
        detached.microphone.phase,
      ).equals(PreJoinCapturePhase.uninitialized);

      container.dispose();
      await Future<void>.delayed(Duration.zero);
      verifyNever(media.cameraTrack!.stop);
      verifyNever(media.cameraTrack!.dispose);
      verifyNever(media.microphoneTrack!.stop);
      verifyNever(media.microphoneTrack!.dispose);
    },
  );

  test('provider disposal stops tracks that were not transferred', () async {
    final factory = _PreviewTrackFactory();
    final container = _createContainer(factory);
    await _waitUntilInitialized(container);

    container.dispose();
    await Future<void>.delayed(Duration.zero);

    verify(factory.videoTracks.single.stop).called(1);
    verify(factory.videoTracks.single.dispose).called(1);
    verify(factory.audioTracks.single.stop).called(1);
    verify(factory.audioTracks.single.dispose).called(1);
  });

  test('failed join reset creates a fresh sequential capture pair', () async {
    final factory = _PreviewTrackFactory();
    final container = _createContainer(factory);
    addTearDown(container.dispose);
    await _waitUntilInitialized(container);
    final controller = container.read(
      preJoinMediaControllerProvider(_sessionSlug).notifier,
    );
    final first = await controller.takeForJoin();

    final resetState = await controller.resetAfterFailedJoin();
    final second = await controller.takeForJoin();

    check(resetState.initializationComplete).equals(true);
    check(factory.videoTracks).length.equals(2);
    check(factory.audioTracks).length.equals(2);
    check(second.cameraTrack).not((it) => it.identicalTo(first.cameraTrack));
    check(
      second.microphoneTrack,
    ).not((it) => it.identicalTo(first.microphoneTrack));
    verifyNever(first.cameraTrack!.stop);
    verifyNever(first.microphoneTrack!.stop);
  });
}
