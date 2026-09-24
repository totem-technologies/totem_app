import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/smart_name_text.dart';

void main() {
  Future<void> pumpName(
    WidgetTester tester,
    String name, {
    double width = 300,
    double threshold = 10,
    TextStyle? style = const TextStyle(fontFamily: 'Ahem', fontSize: 16),
  }) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: width,
          child: SmartNameText(
            name: name,
            style: style,
            abbreviationThreshold: threshold,
          ),
        ),
      ),
    ),
  );

  String renderedName(WidgetTester tester) =>
      tester.widget<Text>(find.byType(Text)).data!;

  testWidgets('trims a full Unicode name', (tester) async {
    await pumpName(tester, '  José 🚀 García  ');

    final text = tester.widget<Text>(find.byType(Text));
    check(text.data).equals('José 🚀 García');
  });

  testWidgets(
    'abbreviates below the fit boundary and expands when space returns',
    (tester) async {
      await pumpName(tester, 'John Smith', width: 100);
      check(renderedName(tester)).equals('John Smith');
      check(
        tester.widget<Text>(find.byType(Text)).textAlign,
      ).equals(TextAlign.center);

      await pumpName(tester, 'John Smith', width: 99);
      check(renderedName(tester)).equals('John S.');

      await pumpName(tester, 'John Smith', width: 100);
      check(renderedName(tester)).equals('John Smith');
    },
  );

  testWidgets(
    'uses the requested font threshold to decide when to abbreviate',
    (tester) async {
      await pumpName(tester, 'John Smith', width: 150);
      check(renderedName(tester)).equals('John Smith');

      await pumpName(tester, 'John Smith', width: 150, threshold: 20);
      check(renderedName(tester)).equals('John S.');
    },
  );

  testWidgets('keeps single-word names intact at narrow widths', (
    tester,
  ) async {
    await pumpName(tester, 'Madonna', width: 10);
    check(renderedName(tester)).equals('Madonna');
  });

  testWidgets(
    'uses the first word and uppercase last initial despite repeated spaces',
    (tester) async {
      await pumpName(tester, '  Bruno  Oliveira  silva  ', width: 50);
      check(renderedName(tester)).equals('Bruno S.');
    },
  );

  testWidgets('preserves an entire emoji grapheme as the last-name initial', (
    tester,
  ) async {
    await pumpName(tester, 'Family 👨‍👩‍👧‍👦', width: 10);
    check(renderedName(tester)).equals('Family 👨‍👩‍👧‍👦.');

    await pumpName(tester, '🎉 🎊 🎈', width: 10);
    check(renderedName(tester)).equals('🎉 🎈.');
  });

  testWidgets('handles whitespace-only names and a missing style', (
    tester,
  ) async {
    await pumpName(tester, '   ', style: null);
    check(renderedName(tester)).equals('');

    await pumpName(tester, 'John Doe', style: null);
    check(renderedName(tester)).equals('John Doe');
  });
}
