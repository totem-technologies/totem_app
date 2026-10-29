import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/widgets/update_available_dialog.dart';

void main() {
  Future<void> pumpDialog(
    WidgetTester tester, {
    required UpdateAvailableDialog dialog,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => dialog,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  group('UpdateAvailableDialog', () {
    testWidgets('renders title, message, prompt, and actions', (tester) async {
      var updated = false;
      var later = false;

      await pumpDialog(
        tester,
        dialog: UpdateAvailableDialog(
          title: 'Update available',
          message: 'A newer version is available.',
          prompt: 'Would you like to update now?',
          updateButtonText: 'Update',
          onUpdate: () => updated = true,
          laterButtonText: 'Later',
          onLater: () => later = true,
        ),
      );

      check(tester.widgetList(find.text('Update available'))).length.equals(1);
      check(
        tester.widgetList(find.text('A newer version is available.')),
      ).length.equals(1);
      check(
        tester.widgetList(find.text('Would you like to update now?')),
      ).length.equals(1);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Update'));
      await tester.pump();
      check(updated).isTrue();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Later'));
      await tester.pump();
      check(later).isTrue();
    });

    testWidgets('hides Later when not provided', (tester) async {
      await pumpDialog(
        tester,
        dialog: UpdateAvailableDialog(
          title: 'Update available',
          message: 'Please update to continue.',
          updateButtonText: 'Update',
          onUpdate: () {},
        ),
      );

      check(tester.widgetList(find.text('Update'))).length.equals(1);
      check(tester.widgetList(find.text('Later'))).length.equals(0);
    });

    testWidgets('hides Later when callback is missing', (tester) async {
      await pumpDialog(
        tester,
        dialog: UpdateAvailableDialog(
          title: 'Update available',
          message: 'A newer version is available.',
          updateButtonText: 'Update',
          onUpdate: () {},
          laterButtonText: 'Later',
          // onLater omitted on purpose
        ),
      );

      check(tester.widgetList(find.text('Later'))).length.equals(0);
    });

    testWidgets('omits prompt when null', (tester) async {
      await pumpDialog(
        tester,
        dialog: UpdateAvailableDialog(
          title: 'Update available',
          message: 'Please update to continue.',
          updateButtonText: 'Update',
          onUpdate: () {},
        ),
      );

      check(
        tester.widgetList(find.text('Would you like to update now?')),
      ).length.equals(0);
    });
  });
}
