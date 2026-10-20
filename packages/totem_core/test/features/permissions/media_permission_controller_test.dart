import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/permissions/adapters/media_permission_adapter.dart';
import 'package:totem_core/features/permissions/media_permission_controller.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';

import '../../setup.dart';
import 'fake_media_permission_adapter.dart';

const _chrome = WebPlatform(browser: WebBrowser.chrome, os: HostOs.macos);
const _firefox = WebPlatform(browser: WebBrowser.firefox, os: HostOs.macos);

ProviderContainer _container(
  FakeMediaPermissionAdapter adapter, {
  PlatformInfo platform = const IosApp(),
}) {
  final container = ProviderContainer(
    overrides: [
      platformInfoProvider.overrideWithValue(platform),
      mediaPermissionAdapterProvider.overrideWithValue(adapter),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Reads the controller and waits for its first query to land.
Future<MediaPermissions> _loaded(ProviderContainer container) async {
  container.read(mediaPermissionControllerProvider);
  await container.read(mediaPermissionControllerProvider.notifier).refresh();
  // Read into a nullable local: inferring read's type from a non-nullable
  // return breaks Riverpod's subscription.
  final MediaPermissions? state = container.read(
    mediaPermissionControllerProvider,
  );
  return state!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setupAppConfig);
  silenceLogger();

  test('X1: null until the first query completes', () async {
    final adapter = FakeMediaPermissionAdapter()..queryGate = Completer();
    final container = _container(adapter);
    check(container.read(mediaPermissionControllerProvider)).isNull();
    adapter.queryGate!.complete();
    await container.read(mediaPermissionControllerProvider.notifier).refresh();
    check(container.read(mediaPermissionControllerProvider)).equals(
      const MediaPermissions(
        camera: MediaPermission.granted,
        microphone: MediaPermission.granted,
      ),
    );
  });

  test('X1: state survives with no listeners', () async {
    final container = _container(FakeMediaPermissionAdapter());
    await _loaded(container);
    await container.pump();
    check(container.read(mediaPermissionControllerProvider)).isNotNull();
  });

  test('W4: no query support leaves both unknown, but known', () async {
    final container = _container(
      FakeMediaPermissionAdapter(camera: null, microphone: null),
      platform: _firefox,
    );
    check(await _loaded(container)).equals(const MediaPermissions());
  });

  test('A2: a remembered refusal survives an unchanged status', () async {
    final adapter = FakeMediaPermissionAdapter(
      microphone: MediaPermission.unknown,
      requestResults: {MediaKind.microphone: MediaPermission.blocked},
    );
    final container = _container(adapter, platform: const AndroidApp());
    await _loaded(container);
    final notifier = container.read(mediaPermissionControllerProvider.notifier);

    check(await notifier.request(MediaKind.microphone))
        .equals(MediaPermission.blocked);
    // Android's status keeps saying denied, which is unknown.
    adapter.queries[MediaKind.microphone] = MediaPermission.unknown;
    await notifier.refresh();
    check(container.read(mediaPermissionControllerProvider)!.microphone)
        .equals(MediaPermission.blocked);
  });

  test('X5: a grant made in Settings is picked up on resume', () async {
    final adapter = FakeMediaPermissionAdapter(
      microphone: MediaPermission.blocked,
    );
    final container = _container(adapter);
    await _loaded(container);

    adapter.queries[MediaKind.microphone] = MediaPermission.granted;
    // The real sequence through Settings and back.
    [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged,
    );
    await pumpEventQueue();

    check(container.read(mediaPermissionControllerProvider)!.microphone)
        .equals(MediaPermission.granted);
  });

  test('X12/WC1: a platform change event refreshes', () async {
    final adapter = FakeMediaPermissionAdapter(camera: MediaPermission.unknown);
    final container = _container(adapter, platform: _chrome);
    await _loaded(container);

    adapter
      ..queries[MediaKind.camera] = MediaPermission.granted
      ..emitChange();
    await pumpEventQueue();

    check(container.read(mediaPermissionControllerProvider)!.camera)
        .equals(MediaPermission.granted);
  });

  test('I8: overlapping refreshes end on the latest answer', () async {
    final adapter = FakeMediaPermissionAdapter(camera: MediaPermission.unknown);
    final container = _container(adapter);
    await _loaded(container);
    final notifier = container.read(mediaPermissionControllerProvider.notifier);

    adapter.queryGate = Completer();
    final first = notifier.refresh();
    adapter.queries[MediaKind.camera] = MediaPermission.granted;
    final second = notifier.refresh();
    adapter.queryGate!.complete();
    await Future.wait([first, second]);

    check(container.read(mediaPermissionControllerProvider)!.camera)
        .equals(MediaPermission.granted);
  });

  test('concurrent requests for one device share one prompt', () async {
    final adapter = FakeMediaPermissionAdapter(
      camera: MediaPermission.unknown,
      requestResults: {MediaKind.camera: MediaPermission.granted},
    );
    final container = _container(adapter);
    await _loaded(container);
    final notifier = container.read(mediaPermissionControllerProvider.notifier);

    await Future.wait([
      notifier.request(MediaKind.camera),
      notifier.request(MediaKind.camera),
    ]);
    check(adapter.requested).deepEquals([MediaKind.camera]);
  });

  test('WS2: web has no separate request', () async {
    final container = _container(
      FakeMediaPermissionAdapter(camera: MediaPermission.unknown),
      platform: _chrome,
    );
    await _loaded(container);
    check(
      await container
          .read(mediaPermissionControllerProvider.notifier)
          .request(MediaKind.camera),
    ).equals(MediaPermission.unknown);
  });

  group('capture outcomes', () {
    Future<CaptureFailure> fail(
      ProviderContainer container,
      MediaKind kind,
      Object error,
    ) => container
        .read(mediaPermissionControllerProvider.notifier)
        .recordCaptureFailure(kind, error, StackTrace.empty);

    test('WS1: capture success overrides a stale prompt query', () async {
      final adapter = FakeMediaPermissionAdapter(
        camera: MediaPermission.unknown,
      );
      final container = _container(adapter, platform: _chrome);
      await _loaded(container);
      final notifier = container.read(
        mediaPermissionControllerProvider.notifier,
      )..recordCaptureSuccess(MediaKind.camera);
      await notifier.refresh();
      check(container.read(mediaPermissionControllerProvider)!.camera)
          .equals(MediaPermission.granted);
    });

    test('W3: a refused capture records the permission', () async {
      final container = _container(
        FakeMediaPermissionAdapter(),
        platform: _chrome,
      );
      await _loaded(container);
      check(
        await fail(
          container,
          MediaKind.camera,
          'NotAllowedError: Permission denied',
        ),
      ).equals(const PermissionRefused(MediaPermission.blocked));
      check(container.read(mediaPermissionControllerProvider)!.camera)
          .equals(MediaPermission.blocked);
    });

    test('X9: a device failure leaves the permission alone', () async {
      final container = _container(
        FakeMediaPermissionAdapter(),
        platform: _chrome,
      );
      await _loaded(container);
      check(
        await fail(
          container,
          MediaKind.camera,
          'NotReadableError: Could not start video source',
        ),
      ).equals(const DeviceFailed(DeviceProblem.inUse));
      check(container.read(mediaPermissionControllerProvider)!.camera)
          .equals(MediaPermission.granted);
    });

    test('WF4: Firefox NotFoundError checks for a listed device', () async {
      final container = _container(
        FakeMediaPermissionAdapter(),
        platform: _firefox,
      );
      await _loaded(container);
      check(await fail(container, MediaKind.camera, 'NotFoundError'))
          .equals(const PermissionRefused(MediaPermission.blockedBySystem));
    });

    test('X4: an unrecognized failure is a failed device', () async {
      final container = _container(FakeMediaPermissionAdapter());
      await _loaded(container);
      check(await fail(container, MediaKind.camera, StateError('boom')))
          .equals(const DeviceFailed(DeviceProblem.failed));
      check(container.read(mediaPermissionControllerProvider)!.camera)
          .equals(MediaPermission.granted);
    });
  });

  test('opens app Settings through the adapter', () async {
    final adapter = FakeMediaPermissionAdapter();
    final container = _container(adapter);
    await container
        .read(mediaPermissionControllerProvider.notifier)
        .openSettings();
    check(adapter.settingsOpened).equals(1);
  });
}
