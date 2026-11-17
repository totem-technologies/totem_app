import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_core/features/sessions/presentation/session_device_effects.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/shared/widgets/notifications.dart';

/// Counts each registration rather than only the first broadcast subscriber.
class _ObservedEvents<T> {
  final _source = StreamController<T>.broadcast(sync: true);
  int registrations = 0;
  int active = 0;
  int cancellations = 0;

  late final Stream<T> stream = Stream<T>.multi((events) {
    registrations++;
    active++;
    final subscription = _source.stream.listen(events.add);
    events.onCancel = () async {
      cancellations++;
      active--;
      await subscription.cancel();
    };
  }, isBroadcast: true);

  void add(T event) => _source.add(event);
  Future<void> close() => _source.close();
}

class _Session extends Mock implements SessionController {}

class _Devices extends SessionDeviceController {
  final attention = _ObservedEvents<MediaKind>();
  final blocked = _ObservedEvents<(MediaKind, TurnOnBlocker)>();

  @override
  Stream<MediaKind> get deviceNeedsAttention => attention.stream;

  @override
  Stream<(MediaKind, TurnOnBlocker)> get turnOnBlocked => blocked.stream;

  @override
  SessionDeviceState build(SessionController session) =>
      const SessionDeviceState(
        selectedCameraDeviceId: null,
        selectedAudioOutputDeviceId: null,
        isSpeakerphoneEnabled: false,
        isMicrophoneEnabled: false,
        isCameraEnabled: false,
        cameraProblem: DeviceProblem.lost,
      );

  Future<void> closeEvents() async {
    await attention.close();
    await blocked.close();
  }
}

class _Host extends StatefulWidget {
  const _Host({required this.revision, required this.showEffects});
  final ValueNotifier<int> revision;
  final ValueNotifier<bool> showEffects;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final notifications = NotificationController();

  @override
  void dispose() {
    notifications.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: ValueListenableBuilder(
        valueListenable: widget.revision,
        builder: (context, revision, _) => ValueListenableBuilder(
          valueListenable: widget.showEffects,
          builder: (context, show, _) => show
              ? SessionDeviceEffects(
                  notifications: notifications,
                  child: Text('Room revision $revision'),
                )
              : const Text('Room effects removed'),
        ),
      ),
    ),
  );
}

void main() {
  void effectsTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(
      description,
      body,
      // NotificationBanner uses third-party AutoSizeText, whose measurement
      // TextPainters currently leak. All owned first-party resources stay tracked.
      experimentalLeakTesting: LeakTesting.settings.withIgnored(
        classes: <String>['TextPainter'],
      ),
    );
  }

  effectsTest(
    'rebuilding registers device feedback once and removal rejects late notices',
    (tester) async {
      final session = _Session();
      final devices = _Devices();
      when(() => session.devices).thenReturn(devices);
      final revision = ValueNotifier(0);
      final showEffects = ValueNotifier(true);
      final container = ProviderContainer(
        overrides: [
          currentSessionProvider.overrideWith((_) => session),
          sessionDeviceControllerProvider(session).overrideWith(() => devices),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _Host(revision: revision, showEffects: showEffects),
        ),
      );
      for (var change = 1; change <= 3; change++) {
        revision.value = change;
        await tester.pump();
      }
      check(devices.attention.registrations).equals(1);
      check(devices.blocked.registrations).equals(1);
      check(devices.attention.active).equals(1);
      check(devices.blocked.active).equals(1);

      devices.blocked.add((MediaKind.microphone, TurnOnBlocker.connection));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      check(find.byType(NotificationBanner).evaluate()).length.equals(1);

      showEffects.value = false;
      await tester.pump();
      check(devices.attention.active).equals(0);
      check(devices.blocked.active).equals(0);
      // Let the existing finite notification finish before probing late events.
      await tester.pump(const Duration(seconds: 8));
      await tester.pump(const Duration(milliseconds: 700));
      devices.attention.add(MediaKind.camera);
      devices.blocked.add((MediaKind.camera, TurnOnBlocker.keeperAway));
      await tester.pump();
      check(find.byType(NotificationBanner).evaluate()).isEmpty();
      check(tester.takeException()).isNull();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
      revision.dispose();
      showEffects.dispose();
      await devices.closeEvents();
    },
  );

  effectsTest('replacing a session cancels old device feedback sources', (
    tester,
  ) async {
    final first = _Session();
    final next = _Session();
    final firstDevices = _Devices();
    final nextDevices = _Devices();
    when(() => first.devices).thenReturn(firstDevices);
    when(() => next.devices).thenReturn(nextDevices);
    final selection = ValueNotifier<SessionController?>(first);
    final revision = ValueNotifier(0);
    final showEffects = ValueNotifier(true);
    final container = ProviderContainer(
      overrides: [
        currentSessionProvider.overrideWith((ref) {
          selection.addListener(ref.invalidateSelf);
          ref.onDispose(() => selection.removeListener(ref.invalidateSelf));
          return selection.value;
        }),
        sessionDeviceControllerProvider(first).overrideWith(() => firstDevices),
        sessionDeviceControllerProvider(next).overrideWith(() => nextDevices),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _Host(revision: revision, showEffects: showEffects),
      ),
    );
    selection.value = next;
    await tester.pump();
    check(firstDevices.attention.active).equals(0);
    check(firstDevices.blocked.active).equals(0);
    check(nextDevices.attention.active).equals(1);
    check(nextDevices.blocked.active).equals(1);

    firstDevices.attention.add(MediaKind.camera);
    firstDevices.blocked.add((MediaKind.microphone, TurnOnBlocker.connection));
    await tester.pump();
    check(find.byType(NotificationBanner).evaluate()).isEmpty();
    nextDevices.blocked.add((MediaKind.microphone, TurnOnBlocker.connection));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    check(find.byType(NotificationBanner).evaluate()).length.equals(1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    check(nextDevices.attention.active).equals(0);
    check(nextDevices.blocked.active).equals(0);
    nextDevices.attention.add(MediaKind.camera);
    nextDevices.blocked.add((MediaKind.camera, TurnOnBlocker.keeperAway));
    await tester.pump();
    check(tester.takeException()).isNull();
    container.dispose();
    selection.dispose();
    revision.dispose();
    showEffects.dispose();
    await firstDevices.closeEvents();
    await nextDevices.closeEvents();
  });
}
