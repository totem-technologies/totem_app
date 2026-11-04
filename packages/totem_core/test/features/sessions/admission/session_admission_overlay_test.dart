import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/keeper_admission_panel.dart';
import 'package:totem_core/features/sessions/admission/session_admission_overlay.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart'
    as session_state;
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/session_waiting_queue_button.dart';

import '../livekit_mocks.dart';
import '../session_test_mocks.dart';

class _AdmissionRoom extends FakeRoom {
  _AdmissionRoom(super.participant);

  final listener = _AdmissionEvents();

  @override
  EventsListener<RoomEvent> createListener({bool synchronized = true}) =>
      listener;
}

class _AdmissionEvents implements EventsListener<RoomEvent> {
  final handlers = <Type, List<FutureOr<void> Function(Object?)>>{};

  @override
  CancelListenFunc on<E>(
    FutureOr<void> Function(E event) handler, {
    bool Function(E)? filter,
  }) {
    handlers.putIfAbsent(E, () => []).add((event) {
      final typed = event as E;
      if (filter == null || filter(typed)) return handler(typed);
    });
    return () async {};
  }

  Future<void> trigger<E>(E event) async {
    for (final handler in handlers[E] ?? <FutureOr<void> Function(Object?)>[]) {
      await handler(event);
    }
  }

  @override
  Future<bool> dispose() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RemoteParticipant extends Fake implements RemoteParticipant {
  _RemoteParticipant(this.identity);

  @override
  final String identity;
}

class _SessionController extends Mock implements SessionController {}

class _VideoPlaceholder extends StatefulWidget {
  const _VideoPlaceholder(this.builds);

  final ValueNotifier<int> builds;

  @override
  State<_VideoPlaceholder> createState() => _VideoPlaceholderState();
}

class _VideoPlaceholderState extends State<_VideoPlaceholder> {
  @override
  Widget build(BuildContext context) {
    widget.builds.value++;
    return const SizedBox.expand();
  }
}

class _AdmissionOverlayLayout {
  const _AdmissionOverlayLayout({
    required this.viewport,
    required this.stackSize,
  });

  final Size viewport;
  final Size stackSize;
}

class _AdmissionOverlayHost extends StatelessWidget {
  const _AdmissionOverlayHost({
    required this.layouts,
    required this.videoBuilds,
  });

  final ValueListenable<_AdmissionOverlayLayout> layouts;
  final ValueNotifier<int> videoBuilds;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_AdmissionOverlayLayout>(
      valueListenable: layouts,
      builder: (context, layout, _) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(size: layout.viewport),
          child: Center(
            child: SizedBox(
              key: const Key('admission-overlay-test-stack'),
              width: layout.stackSize.width,
              height: layout.stackSize.height,
              child: Stack(
                children: [
                  _VideoPlaceholder(videoBuilds),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      key: SessionActionBar.actionBarKey,
                      height: 64,
                      width: 300,
                    ),
                  ),
                  const SessionAdmissionOverlay(sessionSlug: 'session'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

void main() {
  testWidgets('fails closed without an active session roster', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [SessionAdmissionOverlay(sessionSlug: 'session')],
            ),
          ),
        ),
      ),
    );

    check(find.byType(KeeperAdmissionPanel).evaluate()).isEmpty();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'updates and toggles the keeper queue without rebuilding video',
    (tester) async {
      final videoBuilds = ValueNotifier(0);
      final layouts = ValueNotifier(
        const _AdmissionOverlayLayout(
          viewport: Size(400, 800),
          stackSize: Size(320, 500),
        ),
      );
      addTearDown(videoBuilds.dispose);
      addTearDown(layouts.dispose);
      final participant = MockLocalParticipant('keeper');
      final room = _AdmissionRoom(participant);
      final session = _SessionController();
      final state = MockSessionRoomState();
      when(() => session.room).thenReturn(room);
      when(() => state.connection).thenReturn(
        const session_state.ConnectionState(
          phase: session_state.SessionPhase.connected,
          state: session_state.RoomConnectionState.connected,
        ),
      );
      when(() => state.roomState).thenReturn(
        const RoomState(
          keeper: 'keeper',
          nextSpeaker: Omittable(''),
          currentSpeaker: Omittable(''),
          status: RoomStatus.active,
          turnState: TurnState.idle,
          sessionSlug: 'session',
          statusDetail: RoomStateStatusDetailActive(ActiveDetail()),
          talkingOrder: [],
          version: 1,
          roundNumber: 1,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentSessionProvider.overrideWith((ref) => session),
            currentSessionStateProvider.overrideWithValue(state),
            currentSessionEventProvider.overrideWith((ref) => null),
            userProfileProvider('guest').overrideWith(
              (ref) => PublicUserSchema(
                profileAvatarType: ProfileAvatarTypeEnum.td,
                dateCreated: DateTime(2024),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: _AdmissionOverlayHost(
                layouts: layouts,
                videoBuilds: videoBuilds,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      check(videoBuilds.value).equals(1);

      final request = AdmissionRequest(
        id: 'request',
        senderIdentity: 'guest',
        recipientIdentity: 'keeper',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        displayName: 'Guest',
      );
      await room.listener.trigger(
        DataReceivedEvent(
          data: AdmissionProtocol.encode(request),
          participant: _RemoteParticipant('guest'),
          topic: AdmissionProtocol.topic,
        ),
      );
      await tester.pump();
      await tester.pump();

      final actionBar = find.byKey(SessionActionBar.actionBarKey);
      final stack = find.byKey(const Key('admission-overlay-test-stack'));
      void checkAboveActionBar(Finder finder) {
        check(
          tester.getRect(finder).bottom,
        ).isLessOrEqual(tester.getRect(actionBar).top - 16);
      }

      void checkTopRight(Finder finder) {
        final bounds = tester.getRect(stack);
        final rect = tester.getRect(finder);
        check(rect.top).equals(bounds.top + 16);
        check(rect.right).equals(bounds.right - 16);
      }

      check(find.byType(KeeperAdmissionPanel).evaluate()).length.equals(1);
      checkAboveActionBar(find.byType(KeeperAdmissionPanel));
      check(videoBuilds.value).equals(1);

      await tester.tap(find.byTooltip('Close admission'));
      await tester.pump();
      check(find.byType(SessionWaitingQueueButton).evaluate()).length.equals(1);
      checkAboveActionBar(find.byType(SessionWaitingQueueButton));
      check(videoBuilds.value).equals(1);

      layouts.value = const _AdmissionOverlayLayout(
        viewport: Size(800, 400),
        stackSize: Size(500, 320),
      );
      await tester.pump();
      await tester.pump();
      checkAboveActionBar(find.byType(SessionWaitingQueueButton));

      await tester.tap(find.byType(SessionWaitingQueueButton));
      await tester.pump();
      check(find.byType(KeeperAdmissionPanel).evaluate()).length.equals(1);
      checkAboveActionBar(find.byType(KeeperAdmissionPanel));

      layouts.value = const _AdmissionOverlayLayout(
        viewport: Size(1200, 900),
        stackSize: Size(700, 500),
      );
      await tester.pump();
      await tester.pump();
      checkTopRight(find.byType(KeeperAdmissionPanel));

      await tester.tap(find.byTooltip('Close admission'));
      await tester.pump();
      check(find.byType(SessionWaitingQueueButton).evaluate()).length.equals(1);
      checkTopRight(find.byType(SessionWaitingQueueButton));

      await tester.pump(const Duration(minutes: 1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.idle();
    },
  );
}
