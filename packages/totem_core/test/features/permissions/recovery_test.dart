import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/permissions/adapters/media_permission_adapter.dart';
import 'package:totem_core/features/permissions/media_control.dart';
import 'package:totem_core/features/permissions/media_permission_controller.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';
import 'package:totem_core/features/permissions/ui/recovery.dart';

import '../../setup.dart';
import 'fake_media_permission_adapter.dart';

/// A microphone whose captures find no device, until [works].
class _FakeMicrophone extends Notifier<DeviceProblem?> {
  static int captures = 0;
  static bool works = false;

  @override
  DeviceProblem? build() => null;

  DeviceProblem? get problem => state;
  set problem(DeviceProblem? problem) => state = problem;

  Future<TurnOnOutcome> turnOn() async {
    captures++;
    state = works ? null : DeviceProblem.notFound;
    return works
        ? const TurnedOn()
        : const TurnOnFailed(DeviceFailed(DeviceProblem.notFound));
  }
}

final _microphoneProvider = NotifierProvider<_FakeMicrophone, DeviceProblem?>(
  _FakeMicrophone.new,
);

void main() {
  setUpAll(setupAppConfig);

  late ProviderContainer container;

  // Like a real capture owner, a capture that works proves the permission.
  MediaControl control() => MediaControl(
    kind: MediaKind.microphone,
    problem: _microphoneProvider,
    turnOn: () async {
      final outcome = await container
          .read(_microphoneProvider.notifier)
          .turnOn();
      if (outcome is TurnedOn) {
        container
            .read(mediaPermissionControllerProvider.notifier)
            .recordCaptureSuccess(MediaKind.microphone);
      }
      return outcome;
    },
  );

  /// A button that runs [action] for the fake microphone.
  Future<void> pumpHarness(
    WidgetTester tester,
    FakeMediaPermissionAdapter adapter,
    Future<void> Function(BuildContext, WidgetRef) action, {
    PlatformInfo platform = const IosApp(),
  }) async {
    _FakeMicrophone.captures = 0;
    _FakeMicrophone.works = false;
    container = ProviderContainer(
      overrides: [
        platformInfoProvider.overrideWithValue(platform),
        mediaPermissionAdapterProvider.overrideWithValue(adapter),
      ],
    );
    addTearDown(container.dispose);
    await container.read(mediaPermissionControllerProvider.notifier).refresh();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => action(context, ref),
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('X13: a retry that fails again explains the fix', (tester) async {
    await pumpHarness(
      tester,
      FakeMediaPermissionAdapter(),
      (context, ref) => recoverMedia(context, ref, control()),
    );
    container.read(_microphoneProvider.notifier).problem = DeviceProblem.lost;

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    check(_FakeMicrophone.captures).equals(1);
    check(find.byType(MediaRecoveryDialog).evaluate()).length.equals(1);
    check(find.text('No microphone found').evaluate()).length.equals(1);
  });

  testWidgets('a retry with explain off leaves the explaining to the screen', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      FakeMediaPermissionAdapter(),
      (context, ref) => recoverMedia(context, ref, control(), explain: false),
    );
    container.read(_microphoneProvider.notifier).problem = DeviceProblem.lost;

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    check(_FakeMicrophone.captures).equals(1);
    check(find.byType(MediaRecoveryDialog).evaluate()).isEmpty();
  });

  testWidgets('X5: the dialog closes once access returns from Settings', (
    tester,
  ) async {
    final adapter = FakeMediaPermissionAdapter(
      microphone: MediaPermission.blocked,
    );
    await pumpHarness(
      tester,
      adapter,
      (context, ref) => showMediaRecoveryDialog(context, control()),
    );
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    check(find.byType(MediaRecoveryDialog).evaluate()).length.equals(1);

    adapter.queries[MediaKind.microphone] = MediaPermission.granted;
    await container.read(mediaPermissionControllerProvider.notifier).refresh();
    await tester.pumpAndSettle();

    check(find.byType(MediaRecoveryDialog).evaluate()).isEmpty();
  });

  testWidgets('a fix closes only the dialog, not a route on top of it', (
    tester,
  ) async {
    final adapter = FakeMediaPermissionAdapter(
      microphone: MediaPermission.blocked,
    );
    late BuildContext buttonContext;
    await pumpHarness(tester, adapter, (context, ref) {
      buttonContext = context;
      return showMediaRecoveryDialog(context, control());
    });
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    showDialog<void>(
      context: buttonContext,
      builder: (_) => const AlertDialog(content: Text('On top')),
    );
    await tester.pumpAndSettle();

    adapter.queries[MediaKind.microphone] = MediaPermission.granted;
    await container.read(mediaPermissionControllerProvider.notifier).refresh();
    await tester.pumpAndSettle();

    check(find.byType(MediaRecoveryDialog).evaluate()).isEmpty();
    check(find.text('On top').evaluate()).length.equals(1);
  });

  testWidgets('a skipped turn-on shows nothing', (tester) async {
    await pumpHarness(
      tester,
      FakeMediaPermissionAdapter(),
      (context, ref) => turnOnMedia(
        context,
        ref,
        MediaControl(
          kind: MediaKind.microphone,
          problem: _microphoneProvider,
          turnOn: () async => const TurnOnSkipped(),
        ),
      ),
    );

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    check(find.byType(MediaRecoveryDialog).evaluate()).isEmpty();
  });

  testWidgets('a grant then a failed capture is explained, then closes', (
    tester,
  ) async {
    final adapter = FakeMediaPermissionAdapter(
      microphone: MediaPermission.unknown,
      requestResults: {MediaKind.microphone: MediaPermission.granted},
    );
    await pumpHarness(
      tester,
      adapter,
      (context, ref) => turnOnMedia(context, ref, control()),
    );

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    check(adapter.requested).deepEquals([MediaKind.microphone]);
    check(find.byType(MediaRecoveryDialog).evaluate()).length.equals(1);
    check(find.text('No microphone found').evaluate()).length.equals(1);

    // Fixed, and tried again from the dialog: it closes once it works.
    _FakeMicrophone.works = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    check(find.byType(MediaRecoveryDialog).evaluate()).isEmpty();
  });

  testWidgets('WS5: the in-app browser fix explains, then copies the link', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpHarness(
      tester,
      FakeMediaPermissionAdapter(microphone: MediaPermission.unsupported),
      (context, ref) => recoverMedia(context, ref, control()),
      platform: const WebPlatform(
        browser: WebBrowser.other,
        os: HostOs.ios,
        inAppBrowser: true,
      ),
    );

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    check(find.byType(MediaRecoveryDialog).evaluate()).length.equals(1);
    await tester.tap(find.text('Copy link'));
    await tester.pump();

    check(copied).isNotNull();
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('WS5: copying the link says so, then resets', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    container = ProviderContainer(
      overrides: [
        platformInfoProvider.overrideWithValue(
          const WebPlatform(
            browser: WebBrowser.other,
            os: HostOs.ios,
            inAppBrowser: true,
          ),
        ),
        mediaPermissionAdapterProvider.overrideWithValue(
          FakeMediaPermissionAdapter(microphone: MediaPermission.unsupported),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(mediaPermissionControllerProvider.notifier).refresh();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: MediaRecoveryBanner(control: control())),
        ),
      ),
    );

    await tester.tap(find.text('Copy link'));
    await tester.pump();
    check(copied).isNotNull();
    check(find.text('Link copied. Paste it in your browser.').evaluate()).length
        .equals(1);

    await tester.pump(const Duration(seconds: 3));
    check(find.text('Copy link').evaluate()).length.equals(1);
  });

  testWidgets('a restricted device offers to learn more, not a fix', (
    tester,
  ) async {
    container = ProviderContainer(
      overrides: [
        platformInfoProvider.overrideWithValue(const IosApp()),
        mediaPermissionAdapterProvider.overrideWithValue(
          FakeMediaPermissionAdapter(microphone: MediaPermission.restricted),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(mediaPermissionControllerProvider.notifier).refresh();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: MediaRecoveryBanner(control: control())),
        ),
      ),
    );

    check(find.text('Learn more').evaluate()).length.equals(1);
    check(find.text('How to fix').evaluate()).isEmpty();
  });

  testWidgets('WC2: a dismissed browser prompt is the answer: no dialog', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      FakeMediaPermissionAdapter(microphone: MediaPermission.unknown),
      (context, ref) => turnOnMedia(
        context,
        ref,
        MediaControl(
          kind: MediaKind.microphone,
          problem: _microphoneProvider,
          turnOn: () async =>
              const TurnOnFailed(PermissionRefused(MediaPermission.unknown)),
        ),
      ),
      platform: const WebPlatform(browser: WebBrowser.chrome, os: HostOs.macos),
    );

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    check(find.byType(MediaRecoveryDialog).evaluate()).isEmpty();
  });

  testWidgets('WS1: check again closes the dialog once the device works', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      FakeMediaPermissionAdapter(microphone: MediaPermission.blocked),
      (context, ref) => showMediaRecoveryDialog(context, control()),
      platform: const WebPlatform(browser: WebBrowser.chrome, os: HostOs.macos),
    );
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    check(find.text('Check again').evaluate()).length.equals(1);

    // Still blocked: the dialog stays.
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    check(find.byType(MediaRecoveryDialog).evaluate()).length.equals(1);

    // Allowed in site settings: the next check closes it.
    _FakeMicrophone.works = true;
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    check(_FakeMicrophone.captures).equals(2);
    check(find.byType(MediaRecoveryDialog).evaluate()).isEmpty();
  });

  testWidgets('A2: Android refusing without a prompt explains Settings', (
    tester,
  ) async {
    final adapter = FakeMediaPermissionAdapter(
      microphone: MediaPermission.denied,
      requestResults: {MediaKind.microphone: MediaPermission.blocked},
    );
    await pumpHarness(
      tester,
      adapter,
      (context, ref) => turnOnMedia(context, ref, control()),
      platform: const AndroidApp(),
    );

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    check(adapter.requested).deepEquals([MediaKind.microphone]);
    check(_FakeMicrophone.captures).equals(0);
    check(find.byType(MediaRecoveryDialog).evaluate()).length.equals(1);
  });

  testWidgets('a refusal at the OS prompt is the answer: no dialog', (
    tester,
  ) async {
    final adapter = FakeMediaPermissionAdapter(
      microphone: MediaPermission.unknown,
      requestResults: {MediaKind.microphone: MediaPermission.blocked},
    );
    await pumpHarness(
      tester,
      adapter,
      (context, ref) => turnOnMedia(context, ref, control()),
    );

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    check(adapter.requested).deepEquals([MediaKind.microphone]);
    check(_FakeMicrophone.captures).equals(0);
    check(find.byType(MediaRecoveryDialog).evaluate()).isEmpty();
  });
}
