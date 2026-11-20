import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/sessions/admission/declined_participants_modal.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';

import '../../../setup.dart';
import 'admission_ui_test_support.dart';

void main() {
  setUpAll(setupAppConfig);

  for (final size in [const Size(360, 640), const Size(1000, 800)]) {
    testWidgets('server declined participants can be allowed at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final guest = admissionParticipant(
        'user-1',
        name: 'User user-1',
        state: 'permanently_declined',
      );
      final service = AdmissionUiService(
        admissionSnapshot(participants: [guest]),
      );
      addTearDown(service.dispose);
      final session = AdmissionUiSession(service);
      final pending = Completer<void>();
      service.onAllow = (_) => pending.future;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentSessionProvider.overrideWith((ref) => session),
            userProfileProvider.overrideWith(
              (ref, slug) async => PublicUserSchema(
                profileAvatarType: ProfileAvatarTypeEnum.td,
                dateCreated: DateTime.utc(2024),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDeclinedParticipantsModal(
                    context,
                    sessionSlug: 'test-session',
                    keeperIdentity: 'keeper-1',
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      check(find.text('User user-1').evaluate()).length.equals(1);
      await tester.tap(find.text('Allow'));
      await tester.pump();
      check(service.allowed).deepEquals([guest]);
      check(find.text('User user-1').evaluate()).length.equals(1);
      service.update(admissionSnapshot());
      pending.complete();
      await tester.pumpAndSettle();
      check(find.text('User user-1').evaluate()).isEmpty();
      check(
        find.text('No participants have been declined').evaluate(),
      ).length.equals(1);
      check(tester.takeException()).isNull();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('shows server errors and retries loading the snapshot', (
    tester,
  ) async {
    final service = AdmissionUiService(null)..error = 'Server unavailable';
    addTearDown(service.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionProvider.overrideWith(
            (ref) => AdmissionUiSession(service),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: DeclinedParticipants(
              sessionSlug: 'test-session',
              keeperIdentity: 'keeper-1',
            ),
          ),
        ),
      ),
    );
    check(find.text('Server unavailable').evaluate()).length.equals(1);
    await tester.tap(find.text('Retry'));
    check(service.syncCalls).equals(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
