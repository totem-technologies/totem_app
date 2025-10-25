import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/main.dart' as app;

import 'setup.dart';

void main() {
  setUpAll(() async {
    setupDotenv();
    await setupFirebase();
  });

  testWidgets('App builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: app.TotemApp()),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(app.TotemApp),
      findsOneWidget,
    );
  });
}
