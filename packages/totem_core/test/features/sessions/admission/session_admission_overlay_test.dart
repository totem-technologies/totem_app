import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/sessions/admission/session_admission_overlay.dart';
import 'package:totem_core/features/sessions/admission/session_admission_scope.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';

import '../../../setup.dart';
import 'admission_ui_test_support.dart';

void main() {
  setUpAll(setupAppConfig);

  testWidgets('scope follows server snapshots and forwards keeper commands', (
    tester,
  ) async {
    final alice = admissionParticipant('alice', name: 'Alice');
    final bob = admissionParticipant('bob', name: 'Bob');
    final service = AdmissionUiService(
      admissionSnapshot(waiting: [alice, bob]),
    );
    addTearDown(service.dispose);
    SessionAdmissionScope? scope;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionProvider.overrideWith(
            (ref) => AdmissionUiSession(service),
          ),
        ],
        child: MaterialApp(
          home: SessionAdmissionOverlay(
            sessionSlug: 'test-session',
            child: Builder(
              builder: (context) {
                scope = SessionAdmissionScope.maybeOf(context);
                return Text('${scope!.requests.length} waiting');
              },
            ),
          ),
        ),
      ),
    );
    check(find.text('2 waiting').evaluate()).length.equals(1);
    await scope!.onDecision(alice, true);
    await scope!.onDeclinePermanently(bob);
    check(
      service.decisions,
    ).deepEquals([(alice, true, false), (bob, false, true)]);
    check(await scope!.onAdmitAll()).isTrue();
    check(service.admitAllCalls).equals(1);
    service.update(admissionSnapshot(waiting: [bob]));
    await tester.pump();
    check(find.text('1 waiting').evaluate()).length.equals(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('panel retries when the server snapshot is unavailable', (
    tester,
  ) async {
    final service = AdmissionUiService(null);
    addTearDown(service.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionProvider.overrideWith(
            (ref) => AdmissionUiSession(service),
          ),
        ],
        child: const MaterialApp(
          home: SessionAdmissionOverlay(
            sessionSlug: 'test-session',
            child: SessionAdmissionPanel(),
          ),
        ),
      ),
    );
    check(
      find.textContaining('Could not load admission data').evaluate(),
    ).length.equals(1);
    check(service.syncCalls).equals(1);
    await tester.tap(find.text('Retry'));
    check(service.syncCalls).equals(2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('retry actions remain available with a stale empty snapshot', (
    tester,
  ) async {
    final service = AdmissionUiService(admissionSnapshot())
      ..error = 'Could not refresh admission'
      ..hasUnresolvedCommand = true;
    addTearDown(service.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionProvider.overrideWith(
            (ref) => AdmissionUiSession(service),
          ),
        ],
        child: const MaterialApp(
          home: SessionAdmissionOverlay(
            sessionSlug: 'test-session',
            child: SessionAdmissionPanel(),
          ),
        ),
      ),
    );
    check(service.syncCalls).equals(1);
    check(find.text('Could not refresh admission').evaluate()).length.equals(1);
    await tester.tap(find.text('Retry refresh'));
    check(service.syncCalls).equals(2);
    await tester.tap(find.text('Retry unresolved command'));
    await tester.pump();
    check(service.unresolvedRetryCalls).equals(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'keeper can open admission when only an unresolved command remains',
    (tester) async {
      final service = AdmissionUiService(admissionSnapshot())
        ..hasUnresolvedCommand = true;
      addTearDown(service.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentSessionProvider.overrideWith(
              (ref) => AdmissionUiSession(service),
            ),
            isCurrentUserKeeperProvider.overrideWith((ref) => true),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SessionAdmissionOverlay(
                sessionSlug: 'test-session',
                child: SessionAdmissionQueueControl(),
              ),
            ),
          ),
        ),
      );
      check(find.text('Admission needs attention').evaluate()).length.equals(1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('keeper sees admission in progress for approved attempts', (
    tester,
  ) async {
    final guest = admissionParticipant('guest', status: 'approved');
    final service = AdmissionUiService(admissionSnapshot(attempts: [guest]));
    addTearDown(service.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionProvider.overrideWith(
            (ref) => AdmissionUiSession(service),
          ),
          isCurrentUserKeeperProvider.overrideWith((ref) => true),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SessionAdmissionOverlay(
              sessionSlug: 'test-session',
              child: SessionAdmissionQueueControl(),
            ),
          ),
        ),
      ),
    );
    check(find.text('Admission in progress').evaluate()).length.equals(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unresolved command can be retried without a snapshot', (
    tester,
  ) async {
    final service = AdmissionUiService(null)..hasUnresolvedCommand = true;
    addTearDown(service.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionProvider.overrideWith(
            (ref) => AdmissionUiSession(service),
          ),
        ],
        child: const MaterialApp(
          home: SessionAdmissionOverlay(
            sessionSlug: 'test-session',
            child: SessionAdmissionPanel(),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Retry unresolved command'));
    await tester.pump();
    check(service.unresolvedRetryCalls).equals(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('opening the panel refreshes each time', (tester) async {
    final service = AdmissionUiService(admissionSnapshot());
    addTearDown(service.dispose);
    final open = ValueNotifier(false);
    addTearDown(open.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionProvider.overrideWith(
            (ref) => AdmissionUiSession(service),
          ),
        ],
        child: MaterialApp(
          home: SessionAdmissionOverlay(
            sessionSlug: 'test-session',
            child: ValueListenableBuilder<bool>(
              valueListenable: open,
              builder: (_, value, _) => value
                  ? const SessionAdmissionPanel()
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    check(service.syncCalls).equals(0);
    open.value = true;
    await tester.pump();
    check(service.syncCalls).equals(1);
    open.value = false;
    await tester.pump();
    open.value = true;
    await tester.pump();
    check(service.syncCalls).equals(2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('panel shows server queue and forwards an admission', (
    tester,
  ) async {
    final guest = admissionParticipant('guest', name: 'Guest');
    final service = AdmissionUiService(admissionSnapshot(waiting: [guest]));
    addTearDown(service.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionProvider.overrideWith(
            (ref) => AdmissionUiSession(service),
          ),
          userProfileProvider.overrideWith(
            (ref, slug) async => PublicUserSchema(
              profileAvatarType: ProfileAvatarTypeEnum.td,
              dateCreated: DateTime.utc(2024),
            ),
          ),
        ],
        child: const MaterialApp(
          home: SessionAdmissionOverlay(
            sessionSlug: 'test-session',
            child: SessionAdmissionPanel(),
          ),
        ),
      ),
    );
    check(find.text('Guest').evaluate()).length.equals(1);
    await tester.tap(find.text('Admit'));
    await tester.pump();
    check(service.decisions).deepEquals([(guest, true, false)]);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
