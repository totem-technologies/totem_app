import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/session_admission_list.dart';
import 'package:totem_core/features/sessions/widgets/session_declined_view.dart';
import 'package:totem_core/features/sessions/widgets/session_entry_info_card.dart';
import 'package:totem_core/features/sessions/widgets/session_entry_notice.dart';
import 'package:totem_core/features/sessions/widgets/session_waiting_queue_button.dart';
import 'package:totem_core/features/sessions/widgets/session_waiting_view.dart';

void main() {
  testWidgets('entry card shows supplied facts and delegates Join', (
    tester,
  ) async {
    var joins = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionEntryInfoCard(
            facts: const [
              SessionEntryFact(
                icon: Icon(Icons.people),
                value: '4',
                label: 'subscribers',
              ),
            ],
            dateLabel: 'Tuesday',
            timeLabel: '18:30',
            onJoin: () => joins++,
          ),
        ),
      ),
    );
    check(find.textContaining('4 subscribers').evaluate().length).equals(1);
    await tester.tap(find.text('Join session'));
    check(joins).equals(1);
  });

  testWidgets(
    'keeper decisions use the displayed guest ID and busy disables them',
    (tester) async {
      String? admitted;
      String? declined;
      final guests = [
        const SessionAdmissionGuest(
          id: 'request-7',
          name: 'Sara',
          expiresLabel: '1:47',
        ),
      ];
      Widget host(bool busy) => MaterialApp(
        home: Scaffold(
          body: SessionAdmissionList(
            guests: guests,
            busy: busy,
            onAdmit: (id) => admitted = id,
            onDecline: (id) => declined = id,
          ),
        ),
      );

      await tester.pumpWidget(host(false));
      await tester.tap(find.text('Admit'));
      check(admitted).equals('request-7');
      await tester.tap(find.text('Decline'));
      check(declined).equals('request-7');

      await tester.pumpWidget(host(true));
      await tester.tap(find.text('Admit'));
      await tester.tap(find.text('Decline'));
      check(admitted).equals('request-7');
      check(declined).equals('request-7');
    },
  );

  testWidgets(
    'decline offer and signup reflect host state, without creating a mock offer',
    (tester) async {
      var signedUp = false;
      var selected = 0;
      Widget host() => MaterialApp(
        home: Scaffold(
          body: SessionDeclinedView(
            message: 'Try another time',
            offer: const Text('Available session'),
            offerDescription: 'Available session',
            onOffer: () => selected++,
            actionLabel: 'Join the next session',
            signedUp: signedUp,
            onSignUp: () => signedUp = true,
          ),
        ),
      );
      await tester.pumpWidget(host());
      await tester.tap(find.text('Available session'));
      check(selected).equals(1);
      await tester.tap(find.text('Join the next session'));
      check(signedUp).isTrue();
      await tester.pumpWidget(host());
      check(find.text("You're signed up").evaluate().length).equals(1);
      await tester.tap(find.text("You're signed up"));
      check(signedUp).isTrue();
    },
  );

  testWidgets('orientation displays only the supplied prompt and completes', (
    tester,
  ) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionOrientationNotice(
            prompt: 'A live prompt',
            onDone: () => closed = true,
          ),
        ),
      ),
    );
    check(find.text('A live prompt').evaluate().length).equals(1);
    await tester.tap(find.text('Got it'));
    check(closed).isTrue();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SessionOrientationNotice(onDone: null)),
      ),
    );
    check(find.text('CURRENT PROMPT').evaluate().isEmpty).isTrue();
  });

  testWidgets('dismissed Keeper queue reopens without counting joined guests', (
    tester,
  ) async {
    var opened = 0;
    Widget host(int count, String? label) => MaterialApp(
      home: Scaffold(
        body: SessionWaitingQueueButton(
          count: count,
          label: label,
          onPressed: () => opened++,
        ),
      ),
    );

    await tester.pumpWidget(host(2, null));
    await tester.tap(find.text('2 people waiting'));
    check(opened).equals(1);

    await tester.pumpWidget(host(0, 'Admission in progress'));
    check(find.textContaining('people waiting').evaluate()).isEmpty();
    await tester.tap(find.text('Admission in progress'));
    check(opened).equals(2);

    await tester.pumpWidget(host(0, null));
    check(find.text('Admission in progress').evaluate()).isEmpty();
  });

  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('waiting shell keeps cancel available at width $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, width == 360 ? 812 : 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var left = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionWaitingView(
              preview: const ColoredBox(color: Colors.blue),
              controls: const SizedBox(height: 52),
              card: SessionWaitingCard(
                title: 'Waiting for approval',
                body: const Text('Your request is pending'),
                actionLabel: 'Cancel request and leave',
                onAction: () => left = true,
              ),
              onLeave: () => left = true,
            ),
          ),
        ),
      );
      check(tester.takeException()).isNull();
      await tester.tap(find.text('Cancel request and leave'));
      check(left).isTrue();
    });
  }
}
