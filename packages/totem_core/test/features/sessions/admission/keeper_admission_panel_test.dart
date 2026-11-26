import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/sessions/admission/keeper_admission_panel.dart';
import 'package:totem_core/features/sessions/admission/session_admission_list.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';

import 'admission_ui_test_support.dart';

void main() {
  for (final count in [1, 8]) {
    testWidgets('portrait queue stays compact and can admit guest $count', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = List.generate(
        count,
        (index) => admissionParticipant('guest-$index', name: 'Guest $index'),
      );
      String? admitted;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            for (final request in requests)
              userProfileProvider(request.identity).overrideWith(
                (ref) => PublicUserSchema(
                  profileAvatarType: ProfileAvatarTypeEnum.td,
                  dateCreated: DateTime.utc(2024),
                ),
              ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: KeeperAdmissionPanel(
                  requests: requests,
                  onDecision: (request, approve) async {
                    if (approve) admitted = request.identity;
                  },
                  onAdmitAll: () {},
                  onClose: () {},
                  busy: false,
                  desktop: false,
                ),
              ),
            ),
          ),
        ),
      );
      check(
        tester.getSize(find.byType(KeeperAdmissionPanel)).height,
      ).isLessThan(640 * 0.36);
      await tester.ensureVisible(find.text('Admit').last);
      await tester.tap(find.text('Admit').last);
      check(admitted).equals(requests.last.identity);
      check(tester.takeException()).isNull();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets(
    'embedded panel fills its rail with readable text in active Session',
    (tester) async {
      final request = admissionParticipant('guest', name: 'Guest');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider(request.identity).overrideWith(
              (ref) => PublicUserSchema(
                profileAvatarType: ProfileAvatarTypeEnum.td,
                dateCreated: DateTime.utc(2024),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 380,
                height: 500,
                child: RoomBackground(
                  status: RoomStatus.active,
                  child: Material(
                    color: AppTheme.cream,
                    child: KeeperAdmissionPanel(
                      requests: [request],
                      onDecision: (_, _) async {},
                      onAdmitAll: () {},
                      onClose: () {},
                      busy: false,
                      desktop: true,
                      embedded: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      check(
        tester.getSize(find.byType(KeeperAdmissionPanel)).height,
      ).equals(500);
      final surfaceLuminance = AppTheme.cream.computeLuminance();
      for (final label in ['Waiting to join', '1 person', 'Guest']) {
        final textColor = tester.widget<Text>(find.text(label)).style!.color!;
        check(
          (surfaceLuminance + 0.05) / (textColor.computeLuminance() + 0.05),
        ).isGreaterOrEqual(4.5);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('ignores actions for a request removed before the tap', (
    tester,
  ) async {
    final request = admissionParticipant('guest', name: 'Guest');
    final requests = ValueNotifier<List<Participant>>([request]);
    addTearDown(requests.dispose);
    var decisions = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider('guest').overrideWith(
            (ref) => PublicUserSchema(
              profileAvatarType: ProfileAvatarTypeEnum.td,
              dateCreated: DateTime.utc(2024),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<List<Participant>>(
              valueListenable: requests,
              builder: (context, current, child) => KeeperAdmissionPanel(
                requests: current,
                onDecision: (_, _) async => decisions++,
                onAdmitAll: () {},
                onClose: () {},
                busy: false,
                desktop: true,
              ),
            ),
          ),
        ),
      ),
    );
    final staleActions = tester.widget<SessionAdmissionList>(
      find.byType(SessionAdmissionList),
    );
    requests.value = [];
    await tester.pump();
    staleActions.onAdmit!('guest');
    staleActions.onDecline!('guest');
    await tester.pump();
    check(decisions).equals(0);
    check(tester.takeException()).isNull();
    check(find.byType(AlertDialog).evaluate()).isEmpty();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keeper can decide separately and admit the remaining queue', (
    tester,
  ) async {
    final requests = [
      admissionParticipant('alice', name: 'Alice'),
      admissionParticipant('bob', name: 'Bob'),
    ];
    final decisions = <String>[];
    var admittedAll = false;
    var dismissed = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          for (final request in requests)
            userProfileProvider(request.identity).overrideWith(
              (ref) => PublicUserSchema(
                profileAvatarType: ProfileAvatarTypeEnum.td,
                dateCreated: DateTime.utc(2024),
              ),
            ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: KeeperAdmissionPanel(
              requests: requests,
              onDecision: (request, approve) async {
                decisions.add('${request.identity}:$approve');
              },
              onAdmitAll: () => admittedAll = true,
              onClose: () => dismissed = true,
              busy: false,
              desktop: true,
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Admit').first);
    await tester.tap(find.text('Admit').first);
    await tester.ensureVisible(find.text('Decline').last);
    await tester.tap(find.text('Decline').last);
    await tester.pumpAndSettle();
    check(decisions).deepEquals(['alice:true']);
    await tester.tap(find.text('Decline').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Admit all'));
    await tester.tap(find.text('Admit all'));
    await tester.tap(find.byTooltip('Close admission'));
    check(decisions).deepEquals(['alice:true', 'bob:false']);
    check(admittedAll).isTrue();
    check(dismissed).isTrue();
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('does not decline a replacement request after confirmation', (
    tester,
  ) async {
    final original = admissionParticipant('alice', name: 'Alice');
    final replacement = original.copyWith(
      attemptId: const Omittable('new-attempt'),
    );
    final requests = ValueNotifier<List<Participant>>([original]);
    addTearDown(requests.dispose);
    var decisions = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider('alice').overrideWith(
            (ref) async => PublicUserSchema(
              profileAvatarType: ProfileAvatarTypeEnum.td,
              dateCreated: DateTime.utc(2024),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<List<Participant>>(
              valueListenable: requests,
              builder: (context, current, _) => KeeperAdmissionPanel(
                requests: current,
                busy: false,
                desktop: true,
                onDecision: (_, _) async {
                  decisions++;
                },
                onAdmitAll: () {},
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    requests.value = [replacement];
    await tester.pump();
    await tester.tap(find.text('Decline').last);
    await tester.pumpAndSettle();
    check(decisions).equals(0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('permanent decline forwards the selected participant', (
    tester,
  ) async {
    final request = admissionParticipant('alice', name: 'Alice');
    Participant? declined;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider('alice').overrideWith(
            (ref) async => PublicUserSchema(
              profileAvatarType: ProfileAvatarTypeEnum.td,
              dateCreated: DateTime.utc(2024),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: KeeperAdmissionPanel(
              requests: [request],
              busy: false,
              desktop: true,
              onDecision: (_, _) async {},
              onDeclinePermanently: (participant) async =>
                  declined = participant,
              onAdmitAll: () {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decline Permanently'));
    await tester.pumpAndSettle();
    check(declined).equals(request);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
