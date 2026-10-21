import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/permissions/adapters/media_permission_adapter.dart';
import 'package:totem_core/features/permissions/media_permission_controller.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_foreground.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_media_controller.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';

import '../../../setup.dart';
import '../../permissions/fake_media_permission_adapter.dart';
import '../livekit_mocks.dart';

const _sessionSlug = 'pre-join-media-test';
const _chrome = WebPlatform(browser: WebBrowser.chrome, os: HostOs.macos);

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

class _ForegroundMonitor implements PreJoinForegroundMonitor {
  _ForegroundMonitor.create({required this.isForeground});

  final changesController = StreamController<bool>.broadcast();
  @override
  final bool requiresForegroundGate = true;
  @override
  bool isForeground;

  @override
  Stream<bool> get changes => changesController.stream;

  void emit(bool value) {
    isForeground = value;
    changesController.add(value);
  }

  @override
  void dispose() {
    unawaited(changesController.close());
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

/// A microphone the browser refuses until the site setting is changed.
class _BlockedThenAllowedMicrophoneFactory extends _PreviewTrackFactory {
  bool allowed = false;

  @override
  Future<LocalAudioTrack?> createAudioTrack() {
    if (!allowed) {
      throw TrackCreateException('NotAllowedError: Permission denied');
    }
    return super.createAudioTrack();
  }
}

/// Fails each device's first capture with an error nobody recognizes.
class _FailsOnceFactory extends _PreviewTrackFactory {
  bool cameraFailed = false;
  bool microphoneFailed = false;

  @override
  Future<LocalVideoTrack?> createVideoTrack(
    CameraCaptureOptions cameraOptions,
  ) {
    if (!cameraFailed) {
      cameraFailed = true;
      throw StateError('unexpected camera failure');
    }
    return super.createVideoTrack(cameraOptions);
  }

  @override
  Future<LocalAudioTrack?> createAudioTrack() {
    if (!microphoneFailed) {
      microphoneFailed = true;
      throw StateError('unexpected microphone failure');
    }
    return super.createAudioTrack();
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
  ValueGetter<PreJoinMediaController>? controller,
  PreJoinForegroundMonitor? foregroundMonitor,
  PlatformInfo platform = _chrome,
  FakeMediaPermissionAdapter? adapter,
}) {
  return ProviderContainer(
    overrides: [
      platformInfoProvider.overrideWithValue(platform),
      mediaPermissionAdapterProvider.overrideWithValue(
        adapter ?? FakeMediaPermissionAdapter(),
      ),
      preJoinPreviewTrackFactoryProvider.overrideWithValue(factory),
      if (foregroundMonitor != null)
        preJoinForegroundMonitorProvider.overrideWithValue(foregroundMonitor),
      if (controller != null)
        preJoinMediaControllerProvider(_sessionSlug).overrideWith(controller),
    ],
  )..listen(
    preJoinMediaControllerProvider(_sessionSlug),
    (_, _) {},
    fireImmediately: true,
  );
}

MediaPermission? _permission(ProviderContainer container, MediaKind kind) {
  final MediaPermissions? permissions = container.read(
    mediaPermissionControllerProvider,
  );
  return permissions?[kind];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setupAppConfig);

  group('native access', () {
    Future<PreJoinMediaState> waitFor(
      ProviderContainer container,
      bool Function(PreJoinMediaState) done,
    ) async {
      for (var attempt = 0; attempt < 50; attempt++) {
        final state = container.read(
          preJoinMediaControllerProvider(_sessionSlug),
        );
        if (done(state)) return state;
        await Future<void>.delayed(Duration.zero);
      }
      throw StateError('Pre-join media did not settle');
    }

    test('X2: waits for access, with both devices off', () async {
      final factory = _PreviewTrackFactory();
      final container = _createContainer(
        factory,
        platform: const IosApp(),
        adapter: FakeMediaPermissionAdapter(
          camera: MediaPermission.unknown,
          microphone: MediaPermission.unknown,
        ),
      );
      addTearDown(container.dispose);

      final state = await _waitUntilInitialized(container);
      check(state.camera.phase).equals(PreJoinCapturePhase.waitingForAccess);
      check(
        state.microphone.phase,
      ).equals(PreJoinCapturePhase.waitingForAccess);
      check(state.preferences.isCameraOn).isFalse();
      check(state.preferences.isMicOn).isFalse();
      check(factory.videoTracks).isEmpty();
      check(factory.audioTracks).isEmpty();
    });

    test('X5: starts capturing once access is granted', () async {
      final factory = _PreviewTrackFactory();
      final container = _createContainer(
        factory,
        platform: const IosApp(),
        adapter: FakeMediaPermissionAdapter(
          camera: MediaPermission.unknown,
          microphone: MediaPermission.unknown,
          requestResults: {
            MediaKind.camera: MediaPermission.granted,
            MediaKind.microphone: MediaPermission.granted,
          },
        ),
      );
      addTearDown(container.dispose);
      await _waitUntilInitialized(container);

      final access = container.read(mediaPermissionControllerProvider.notifier);
      await access.request(MediaKind.microphone);
      await access.request(MediaKind.camera);

      final state = await waitFor(
        container,
        (state) => state.camera.isReady && state.microphone.isReady,
      );
      check(state.preferences.isCameraOn).isTrue();
      check(state.preferences.isMicOn).isTrue();
      check(factory.videoTracks).length.equals(1);
      check(factory.audioTracks).length.equals(1);
    });

    test('X1: captures right away when access is already granted', () async {
      final factory = _PreviewTrackFactory();
      final container = _createContainer(factory, platform: const IosApp());
      addTearDown(container.dispose);

      await waitFor(
        container,
        (state) => state.camera.isReady && state.microphone.isReady,
      );
      check(factory.videoTracks).length.equals(1);
    });

    test('X3: a refused camera stays off while the mic works', () async {
      final factory = _PreviewTrackFactory();
      final container = _createContainer(
        factory,
        platform: const IosApp(),
        adapter: FakeMediaPermissionAdapter(camera: MediaPermission.blocked),
      );
      addTearDown(container.dispose);

      final state = await waitFor(
        container,
        (state) => state.microphone.isReady,
      );
      check(state.camera.phase).equals(PreJoinCapturePhase.waitingForAccess);
      check(factory.videoTracks).isEmpty();
    });
  });

  test(
    'X2: turning on a waiting device while access is granted captures once',
    () async {
      final factory = _PreviewTrackFactory();
      final container = _createContainer(
        factory,
        platform: const IosApp(),
        adapter: FakeMediaPermissionAdapter(
          microphone: MediaPermission.unknown,
          requestResults: {MediaKind.microphone: MediaPermission.granted},
        ),
      );
      addTearDown(container.dispose);
      await _waitUntilInitialized(container);

      // What turnOnMedia does: ask, then capture. The grant also wakes the
      // waiting device, and both must lead to a single capture.
      await container
          .read(mediaPermissionControllerProvider.notifier)
          .request(MediaKind.microphone);
      await container
          .read(preJoinMediaControllerProvider(_sessionSlug).notifier)
          .turnOn(MediaKind.microphone);
      await container
          .read(preJoinMediaControllerProvider(_sessionSlug).notifier)
          .settled();

      check(factory.audioTracks).length.equals(1);
    },
  );

  test(
    'X12: a device that failed restarts when access becomes granted',
    () async {
      final factory = _BlockedThenAllowedMicrophoneFactory();
      final adapter = FakeMediaPermissionAdapter(
        microphone: MediaPermission.unknown,
      );
      final container = _createContainer(factory, adapter: adapter);
      addTearDown(container.dispose);

      final failed = await _waitUntilInitialized(container);
      check(failed.microphone.phase).equals(PreJoinCapturePhase.unavailable);
      check(
        _permission(container, MediaKind.microphone),
      ).equals(MediaPermission.blocked);

      // Allowed in the browser's site settings, without a reload.
      factory.allowed = true;
      adapter
        ..queries[MediaKind.microphone] = MediaPermission.granted
        ..emitChange();
      await pumpEventQueue();
      await container
          .read(preJoinMediaControllerProvider(_sessionSlug).notifier)
          .settled();

      final state = container.read(
        preJoinMediaControllerProvider(_sessionSlug),
      );
      check(state.microphone.isReady).isTrue();
      check(state.preferences.isMicOn).isTrue();
    },
  );

  test('a device turned off stays off when access is granted', () async {
    final factory = _PreviewTrackFactory();
    final adapter = FakeMediaPermissionAdapter(camera: MediaPermission.unknown);
    final container = _createContainer(factory, adapter: adapter);
    addTearDown(container.dispose);
    await _waitUntilInitialized(container);
    final controller = container.read(
      preJoinMediaControllerProvider(_sessionSlug).notifier,
    );
    await controller.turnOff(MediaKind.camera);

    adapter
      ..queries[MediaKind.camera] = MediaPermission.granted
      ..emitChange();
    await pumpEventQueue();
    await controller.settled();

    check(
      container.read(preJoinMediaControllerProvider(_sessionSlug)).camera.phase,
    ).equals(PreJoinCapturePhase.disabled);
    check(factory.videoTracks).length.equals(1);
  });

  test(
    'switching cameras while on captures again with the new facing',
    () async {
      final factory = _PreviewTrackFactory();
      final container = _createContainer(factory);
      addTearDown(container.dispose);
      await _waitUntilInitialized(container);
      final controller = container.read(
        preJoinMediaControllerProvider(_sessionSlug).notifier,
      )..setCameraFacing(CameraFacing.back);
      await pumpEventQueue();
      await controller.settled();

      check(factory.videoTracks).length.equals(2);
      verify(factory.videoTracks.first.stop).called(1);
      final state = container.read(
        preJoinMediaControllerProvider(_sessionSlug),
      );
      check(state.camera.track).identicalTo(factory.videoTracks.last);
      check(
        state.preferences.cameraOptions.cameraPosition,
      ).equals(CameraPosition.back);
    },
  );

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

  test('X4: an unexpected capture failure does not poison a retry', () async {
    final factory = _FailsOnceFactory();
    final container = _createContainer(factory);
    addTearDown(container.dispose);

    final failedState = await _waitUntilInitialized(container);
    check(failedState.camera.phase).equals(PreJoinCapturePhase.unavailable);
    check(failedState.camera.problem).equals(DeviceProblem.failed);
    check(failedState.microphone.phase).equals(PreJoinCapturePhase.unavailable);
    check(failedState.microphone.problem).equals(DeviceProblem.failed);

    final controller = container.read(
      preJoinMediaControllerProvider(_sessionSlug).notifier,
    );
    await controller.turnOn(MediaKind.camera);
    await controller.turnOn(MediaKind.microphone);
    final recoveredState = container.read(
      preJoinMediaControllerProvider(_sessionSlug),
    );

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
    check(state.camera.problem).equals(DeviceProblem.notFound);
    check(
      _permission(container, MediaKind.microphone),
    ).equals(MediaPermission.granted);

    final media = await container
        .read(preJoinMediaControllerProvider(_sessionSlug).notifier)
        .takeForJoin();
    check(media.cameraTrack).isNull();
    check(media.microphoneTrack).identicalTo(factory.audioTracks.single);
  });

  test('typed track creation permission errors are classified', () async {
    final container = _createContainer(_PermissionDeniedCameraFactory());
    addTearDown(container.dispose);

    final state = await _waitUntilInitialized(container);

    check(state.camera.phase).equals(PreJoinCapturePhase.unavailable);
    check(
      _permission(container, MediaKind.camera),
    ).equals(MediaPermission.blocked);
  });

  test(
    'W9: camera permission revocation invalidates ready preview media',
    () async {
      final factory = _PreviewTrackFactory();
      final container = _createContainer(factory);
      addTearDown(container.dispose);
      await _waitUntilInitialized(container);

      factory.videoTracks.single.mockMediaStreamTrack.onEnded?.call();

      final state = container.read(
        preJoinMediaControllerProvider(_sessionSlug),
      );
      check(state.camera.phase).equals(PreJoinCapturePhase.unavailable);
      check(state.camera.track).isNull();
      await pumpEventQueue();
      check(
        container
            .read(preJoinMediaControllerProvider(_sessionSlug))
            .camera
            .problem,
      ).equals(DeviceProblem.lost);
      final media = await container
          .read(preJoinMediaControllerProvider(_sessionSlug).notifier)
          .takeForJoin();
      check(media.cameraTrack).isNull();
    },
  );

  test(
    'W9: microphone permission revocation invalidates ready preview media',
    () async {
      final factory = _PreviewTrackFactory();
      final container = _createContainer(factory);
      addTearDown(container.dispose);
      await _waitUntilInitialized(container);

      factory.audioTracks.single.mockMediaStreamTrack.onEnded?.call();

      final state = container.read(
        preJoinMediaControllerProvider(_sessionSlug),
      );
      check(state.microphone.phase).equals(PreJoinCapturePhase.unavailable);
      check(state.microphone.track).isNull();
      await pumpEventQueue();
      check(
        container
            .read(preJoinMediaControllerProvider(_sessionSlug))
            .microphone
            .problem,
      ).equals(DeviceProblem.lost);
    },
  );

  test('hidden foreground gate defers camera and resumes it once', () async {
    final factory = _PreviewTrackFactory();
    final foreground = _ForegroundMonitor.create(isForeground: false);
    final container = _createContainer(factory, foregroundMonitor: foreground);
    addTearDown(() {
      foreground.dispose();
      container.dispose();
    });

    await Future<void>.delayed(Duration.zero);
    check(factory.videoTracks).isEmpty();
    check(factory.audioTracks).length.equals(1);
    check(
      container.read(preJoinMediaControllerProvider(_sessionSlug)).camera.phase,
    ).equals(PreJoinCapturePhase.waitingForForeground);

    foreground
      ..emit(true)
      ..emit(true);
    final state = await _waitUntilInitialized(container);

    check(factory.videoTracks).length.equals(1);
    check(state.camera.isReady).isTrue();
  });

  test(
    'backgrounded in-flight camera is disposed before foreground retry',
    () async {
      final factory = _DelayedCameraFactory();
      final foreground = _ForegroundMonitor.create(isForeground: true);
      final container = _createContainer(
        factory,
        foregroundMonitor: foreground,
      );
      addTearDown(() {
        foreground.dispose();
        container.dispose();
      });
      await Future<void>.delayed(Duration.zero);
      check(factory.cameraRequested).isTrue();

      foreground.emit(false);
      factory.gate.complete();
      for (
        var attempt = 0;
        attempt < 20 && factory.videoTracks.isEmpty;
        attempt++
      ) {
        await Future<void>.delayed(Duration.zero);
      }

      final staleTrack = factory.videoTracks.single;
      verify(staleTrack.stop).called(1);
      verify(staleTrack.dispose).called(1);
      check(
        container
            .read(preJoinMediaControllerProvider(_sessionSlug))
            .camera
            .phase,
      ).equals(PreJoinCapturePhase.waitingForForeground);

      foreground.emit(true);
      await _waitUntilInitialized(container);
      check(factory.videoTracks).length.equals(2);
    },
  );

  test(
    'camera disabled while deferred does not start after foreground',
    () async {
      final factory = _PreviewTrackFactory();
      final foreground = _ForegroundMonitor.create(isForeground: false);
      final container = _createContainer(
        factory,
        foregroundMonitor: foreground,
      );
      addTearDown(() {
        foreground.dispose();
        container.dispose();
      });
      await Future<void>.delayed(Duration.zero);

      await container
          .read(preJoinMediaControllerProvider(_sessionSlug).notifier)
          .turnOff(MediaKind.camera);
      foreground.emit(true);
      await Future<void>.delayed(Duration.zero);

      check(factory.videoTracks).isEmpty();
      check(
        container
            .read(preJoinMediaControllerProvider(_sessionSlug))
            .camera
            .phase,
      ).equals(PreJoinCapturePhase.disabled);
    },
  );

  test('terminal release stops preview tracks and prevents restart', () async {
    final factory = _PreviewTrackFactory();
    final container = _createContainer(factory);
    addTearDown(container.dispose);
    await _waitUntilInitialized(container);

    final controller = container.read(
      preJoinMediaControllerProvider(_sessionSlug).notifier,
    );
    await controller.releaseForTerminalOutcome();
    await controller.turnOn(MediaKind.camera);

    verify(factory.videoTracks.single.stop).called(1);
    verify(factory.videoTracks.single.dispose).called(1);
    verify(factory.audioTracks.single.stop).called(1);
    verify(factory.audioTracks.single.dispose).called(1);
    check(factory.videoTracks).length.equals(1);
  });

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
    final toggle = controller.turnOff(MediaKind.microphone);
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
    final toggleOff = controller
        .turnOff(MediaKind.microphone)
        .whenComplete(() => toggleCompleted = true);
    await Future<void>.delayed(Duration.zero);

    check(toggleCompleted).equals(false);
    check(factory.audioTracks).isEmpty();

    factory.gate.complete();
    await toggleOff;
    await controller.turnOn(MediaKind.microphone);
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
    final toggle = controller.turnOff(MediaKind.microphone);
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
