import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_widgetbook/config.dart';

/// The args panel rebuilds the story above the catalog frame. The frame's
/// navigator must show that new child. If it keeps the first page, changing
/// role or phase does nothing on screen.
void main() {
  testWidgets('the preview shows the story the args panel just built', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(label: 'Too early'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const _Host(label: 'Keeper'));
    await tester.pump();

    check(find.text('Too early').evaluate()).isEmpty();
    check(find.text('Keeper').evaluate()).isNotEmpty();
  });
}

class _Host extends StatelessWidget {
  const _Host({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return config.appBuilder(context, Text(label));
  }
}
