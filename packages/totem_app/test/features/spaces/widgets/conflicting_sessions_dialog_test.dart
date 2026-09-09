import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/features/spaces/widgets/conflicting_sessions_dialog.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';

MobileSpaceDetailSchema _space(String slug, String title) {
  return MobileSpaceDetailSchema(
    slug: slug,
    title: title,
    imageLink: null,
    shortDescription: 'A test space',
    content: '',
    author: PublicUserSchema(
      profileAvatarType: ProfileAvatarTypeEnum.td,
      dateCreated: DateTime.utc(2026),
    ),
    category: null,
    subscribers: 1,
    recurring: null,
    price: 0,
    nextEvents: const [],
  );
}

SessionDetailSchema _session({
  required String slug,
  required String title,
  required DateTime start,
}) {
  return SessionDetailSchema(
    slug: slug,
    title: title,
    space: _space('$slug-space', '$title Space'),
    content: '',
    seatsLeft: 5,
    duration: 60,
    start: start,
    attending: slug == 'existing-session',
    open: true,
    started: false,
    cancelled: false,
    joinable: false,
    ended: false,
    rsvpUrl: '/rsvp/$slug',
    joinUrl: null,
    subscribeUrl: '/subscribe/$slug',
    calLink: '/calendar/$slug',
    subscribed: true,
    userTimezone: 'UTC',
    meetingProvider: MeetingProviderEnum.livekit,
  );
}

void main() {
  late SessionDetailSchema existingSession;
  late SessionDetailSchema newSession;

  setUp(() {
    final start = DateTime.utc(2026, 8, 20, 15);
    existingSession = _session(
      slug: 'existing-session',
      title: 'Existing Session',
      start: start,
    );
    newSession = _session(
      slug: 'new-session',
      title: 'New Session',
      start: start,
    );
  });

  Future<void> showConflict(
    WidgetTester tester, {
    required Future<bool> Function() onSwitch,
    ValueChanged<bool?>? onResult,
    List<SessionDetailSchema>? conflictingSessions,
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    final hostKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            Directionality(textDirection: textDirection, child: child!),
        home: Scaffold(body: SizedBox(key: hostKey)),
      ),
    );

    unawaited(
      showConflictingSessionsDialog(
        hostKey.currentContext!,
        SessionConflictSchema(
          message: 'Conflict',
          conflictingSessions: conflictingSessions ?? [existingSession],
        ),
        newSession,
        onSwitch,
      ).then((result) => onResult?.call(result)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the existing and new sessions in the correct order', (
    tester,
  ) async {
    await showConflict(tester, onSwitch: () async => true);

    expect(find.text('You have a session at this time.'), findsOneWidget);
    expect(
      find.text(
        'To join New Session, you’ll need to give up your spot in Existing Session.',
      ),
      findsOneWidget,
    );
    expect(find.text('Your current session'), findsOneWidget);
    expect(find.text('Existing Session'), findsOneWidget);
    expect(find.text('New session'), findsOneWidget);
    expect(find.text('New Session'), findsOneWidget);

    final description = tester.widget<Text>(
      find.text(
        'To join New Session, you’ll need to give up your spot in Existing Session.',
      ),
    );
    final spans = (description.textSpan! as TextSpan).children!
        .whereType<TextSpan>();
    for (final sessionName in ['New Session', 'Existing Session']) {
      expect(
        spans.singleWhere((span) => span.text == sessionName).style?.fontWeight,
        FontWeight.w500,
      );
    }
  });

  testWidgets('formats three conflicting session names as a natural list', (
    tester,
  ) async {
    final start = existingSession.start;
    await showConflict(
      tester,
      onSwitch: () async => true,
      conflictingSessions: [
        existingSession,
        _session(slug: 'second-session', title: 'Second Session', start: start),
        _session(slug: 'third-session', title: 'Third Session', start: start),
      ],
    );

    const description =
        'To join New Session, you’ll need to give up your spot in '
        'Existing Session, Second Session, and Third Session.';
    expect(find.text(description), findsOneWidget);

    final text = tester.widget<Text>(find.text(description));
    final spans = (text.textSpan! as TextSpan).children!.whereType<TextSpan>();
    for (final sessionName in [
      'Existing Session',
      'Second Session',
      'Third Session',
    ]) {
      expect(
        spans.singleWhere((span) => span.text == sessionName).style?.fontWeight,
        FontWeight.w500,
      );
    }
    expect(
      spans.singleWhere((span) => span.text == ', and ').style?.fontWeight,
      isNull,
    );
  });

  testWidgets('lays out session cards as a column in portrait', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await showConflict(tester, onSwitch: () async => true);

    final layout = find.byKey(
      const ValueKey('conflicting-sessions-vertical-layout'),
    );
    expect(layout, findsOneWidget);
    final arrow = tester.widget<RotatedBox>(
      find.descendant(of: layout, matching: find.byType(RotatedBox)),
    );
    expect(arrow.quarterTurns, -1);
    expect(
      tester.getCenter(find.text('Existing Session')).dy,
      lessThan(tester.getCenter(find.text('New Session')).dy),
    );
  });

  testWidgets('lays out session cards as a row in landscape', (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await showConflict(tester, onSwitch: () async => true);

    final layout = find.byKey(
      const ValueKey('conflicting-sessions-horizontal-layout'),
    );
    expect(layout, findsOneWidget);
    final arrow = tester.widget<RotatedBox>(
      find.descendant(of: layout, matching: find.byType(RotatedBox)),
    );
    expect(arrow.quarterTurns, 2);
    expect(
      tester.getCenter(find.text('Existing Session')).dx,
      lessThan(tester.getCenter(find.text('New Session')).dx),
    );
  });

  testWidgets('points the horizontal arrow toward the new session in RTL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await showConflict(
      tester,
      onSwitch: () async => true,
      textDirection: TextDirection.rtl,
    );

    final layout = find.byKey(
      const ValueKey('conflicting-sessions-horizontal-layout'),
    );
    final arrow = tester.widget<RotatedBox>(
      find.descendant(of: layout, matching: find.byType(RotatedBox)),
    );
    expect(arrow.quarterTurns, 0);
    expect(
      tester.getCenter(find.text('Existing Session')).dx,
      greaterThan(tester.getCenter(find.text('New Session')).dx),
    );
  });

  testWidgets('switches sessions and closes only after success', (
    tester,
  ) async {
    var switchCalls = 0;
    bool? dialogResult;
    await showConflict(
      tester,
      onSwitch: () async {
        switchCalls++;
        return true;
      },
      onResult: (result) => dialogResult = result,
    );

    await tester.tap(find.text('Switch Sessions'));
    await tester.pumpAndSettle();

    expect(switchCalls, 1);
    expect(dialogResult, isTrue);
    expect(find.text('You have a session at this time.'), findsNothing);
  });

  testWidgets('keeps the dialog open when switching fails', (tester) async {
    await showConflict(tester, onSwitch: () async => false);

    await tester.tap(find.text('Switch Sessions'));
    await tester.pumpAndSettle();

    expect(find.text('You have a session at this time.'), findsOneWidget);
  });
}
