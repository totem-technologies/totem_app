import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_web/core/navigation/version_screen.dart';

void main() {
  group('VersionScreen', () {
    testWidgets('shows version metadata tiles', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VersionScreen()));
      await tester.pump();

      expect(find.text('Version'), findsOneWidget);
      expect(find.text('Build number'), findsOneWidget);
      expect(find.text('Environment'), findsOneWidget);
      expect(find.text('Commit SHA'), findsOneWidget);
      expect(find.text('Deployed at'), findsOneWidget);
    });

    testWidgets('shows local build message when commit is unknown', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: VersionScreen()));
      await tester.pump();

      // When COMMIT_SHA is not set via --web-define (as in test context),
      // the "Deployed at" row falls back to the local build message.
      expect(find.text('Local development build'), findsOneWidget);
    });
  });
}
