import 'dart:async';

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
    return super.createVideoTrack(cameraOptions);
  }
}

class _DelayedMicrophoneFactory extends _PreviewTrackFactory {
  final gate = Completer<void>();
  bool microphoneRequested = false;

  @override
  Future<LocalAudioTrack?> createAudioTrack() async {
    microphoneRequested = true;
    await gate.future;
    return super.createAudioTrack();
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
    final state = container.read(
      preJoinMediaControllerProvider(_sessionSlug),
    );
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
        preJoinMediaControllerProvider(
          _sessionSlug,
        ).overrideWith(controller),
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

    await expectLater(failed, throwsStateError);
    await expectLater(queue.pending, completes);
    expect(await queue.schedule(() async => 42), 42);
  });

  test('failed initial future does not poison media retry', () async {
    final factory = _PreviewTrackFactory();
    final container = _createContainer(
      factory,
      controller: _ThrowingInitializationController.new,
    );
    addTearDown(container.dispose);

    final failedState = await _waitUntilInitialized(container);
    expect(failedState.camera.phase, PreJoinCapturePhase.unavailable);
    expect(failedState.microphone.phase, PreJoinCapturePhase.unavailable);

    final recoveredState = await container
        .read(preJoinMediaControllerProvider(_sessionSlug).notifier)
        .retryFailedMedia();

    expect(recoveredState.camera.isReady, isTrue);
    expect(recoveredState.microphone.isReady, isTrue);
  });

  test('camera unavailable still allows a microphone-only web join', () async {
    final factory = _UnavailableCameraFactory();
    final container = _createContainer(factory);
    addTearDown(container.dispose);

    final state = await _waitUntilInitialized(container);
    expect(state.camera.phase, PreJoinCapturePhase.unavailable);
    expect(state.microphone.phase, PreJoinCapturePhase.ready);
    expect(state.canJoinOnWeb, isTrue);

    final media = await container
        .read(preJoinMediaControllerProvider(_sessionSlug).notifier)
        .takeForJoin();
    expect(media.cameraTrack, isNull);
    expect(media.microphoneTrack, same(factory.audioTracks.single));
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
    expect(state.canJoinOnWeb, isFalse);
  });

  test('typed track creation permission errors are classified', () async {
    final container = _createContainer(_PermissionDeniedCameraFactory());
    addTearDown(container.dispose);

    final state = await _waitUntilInitialized(container);

    expect(state.camera.phase, PreJoinCapturePhase.permissionDenied);
    expect(state.canJoinOnWeb, isFalse);
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
      expect(state.camera.phase, PreJoinCapturePhase.permissionDenied);
      expect(state.camera.track, isNull);
      expect(state.canJoinOnWeb, isFalse);
      await expectLater(
        container
            .read(preJoinMediaControllerProvider(_sessionSlug).notifier)
            .takeForJoin(requireUsableMedia: true),
        throwsA(isA<PreJoinMediaPermissionDeniedException>()),
      );
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
      expect(state.microphone.phase, PreJoinCapturePhase.permissionDenied);
      expect(state.microphone.track, isNull);
      expect(state.canJoinOnWeb, isFalse);
    },
  );

  test('camera and microphone capture are initialized sequentially', () async {
    final factory = _DelayedCameraFactory();
    final container = _createContainer(factory);
    addTearDown(container.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(factory.cameraRequested, isTrue);
    expect(factory.audioTracks, isEmpty);
    factory.gate.complete();
    await _waitUntilInitialized(container);
    expect(factory.videoTracks, hasLength(1));
    expect(factory.audioTracks, hasLength(1));
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

    expect(factory.audioTracks, isEmpty);
    expect(state.microphone.phase, PreJoinCapturePhase.disabled);
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

    expect(toggleCompleted, isFalse);
    expect(factory.audioTracks, isEmpty);

    factory.gate.complete();
    await toggleOff;
    await controller.toggleMicrophone();
    final state = await _waitUntilInitialized(container);

    expect(factory.videoTracks, hasLength(1));
    expect(factory.audioTracks, hasLength(1));
    expect(state.microphone.isReady, isTrue);
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
    expect(
      container
          .read(preJoinMediaControllerProvider(_sessionSlug))
          .microphone
          .phase,
      PreJoinCapturePhase.disabled,
    );
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

      expect(media.cameraTrack, same(factory.videoTracks.single));
      expect(media.microphoneTrack, same(factory.audioTracks.single));
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
      expect(detached.transferred, isTrue);
      expect(detached.camera.track, isNull);
      expect(detached.camera.phase, PreJoinCapturePhase.uninitialized);
      expect(detached.microphone.track, isNull);
      expect(detached.microphone.phase, PreJoinCapturePhase.uninitialized);

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

    expect(resetState.initializationComplete, isTrue);
    expect(factory.videoTracks, hasLength(2));
    expect(factory.audioTracks, hasLength(2));
    expect(second.cameraTrack, isNot(same(first.cameraTrack)));
    expect(second.microphoneTrack, isNot(same(first.microphoneTrack)));
    verifyNever(first.cameraTrack!.stop);
    verifyNever(first.microphoneTrack!.stop);
  });
}
