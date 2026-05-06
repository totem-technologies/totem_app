import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/features/sessions/widgets/smart_name_text.dart';

void main() {
  group('SmartNameText', () {
    Future<void> pumpSmartNameText(
      WidgetTester tester, {
      required String name,
      TextStyle? style,
      double abbreviationThreshold = 10.0,
      TextAlign textAlign = TextAlign.center,
      double? maxWidth,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: maxWidth ?? 200,
                child: SmartNameText(
                  name: name,
                  style: style,
                  abbreviationThreshold: abbreviationThreshold,
                  textAlign: textAlign,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('displays full name when it fits', (tester) async {
      await pumpSmartNameText(
        tester,
        name: 'John',
        style: const TextStyle(fontSize: 16),
        maxWidth: 200,
      );

      expect(find.text('John'), findsOneWidget);
    });

    testWidgets('abbreviates name when it does not fit', (
      tester,
    ) async {
      // Use a very long name and a small width to force abbreviation
      await pumpSmartNameText(
        tester,
        name: 'Christopher Alexander Montgomery',
        style: const TextStyle(fontSize: 16),
        maxWidth: 80,
      );

      // Should show abbreviated form: "Christopher M."
      final text = find.byType(Text);
      expect(text, findsOneWidget);
      final widget = tester.widget<Text>(text);
      expect(widget.data, equals('Christopher M.'));
    });

    testWidgets('handles single word names', (tester) async {
      await pumpSmartNameText(
        tester,
        name: 'Madonna',
        style: const TextStyle(fontSize: 16),
        maxWidth: 100,
      );

      expect(find.text('Madonna'), findsOneWidget);
    });

    testWidgets('handles names with multiple spaces', (
      tester,
    ) async {
      await pumpSmartNameText(
        tester,
        name: 'Bruno  Oliveira  Silva',
        style: const TextStyle(fontSize: 16),
        maxWidth: 100,
      );

      final text = find.byType(Text);
      expect(text, findsOneWidget);
      final widget = tester.widget<Text>(text);
      expect(widget.data, isNotNull);
    });

    testWidgets('trims leading and trailing whitespace', (
      tester,
    ) async {
      await pumpSmartNameText(
        tester,
        name: '  John Doe  ',
        style: const TextStyle(fontSize: 16),
        maxWidth: 200,
      );

      final text = find.byType(Text);
      expect(text, findsOneWidget);
      final widget = tester.widget<Text>(text);
      expect(widget.data, isNotEmpty);
      expect(widget.data?.startsWith(' '), isFalse);
      expect(widget.data?.endsWith(' '), isFalse);
    });

    testWidgets('renders emoji correctly', (tester) async {
      await pumpSmartNameText(
        tester,
        name: '😀 John',
        style: const TextStyle(fontSize: 16),
        maxWidth: 200,
      );

      final text = find.byType(Text);
      expect(text, findsOneWidget);
      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('😀'));
    });

    testWidgets('preserves emoji in full name', (tester) async {
      await pumpSmartNameText(
        tester,
        name: 'Alice 🚀 Bob',
        style: const TextStyle(fontSize: 16),
        maxWidth: 200,
      );

      final text = find.byType(Text);
      expect(text, findsOneWidget);
      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('Alice'));
      expect(widget.data, contains('🚀'));
      expect(widget.data, contains('Bob'));
    });

    testWidgets('abbreviates correctly with emoji in last name', (
      tester,
    ) async {
      await pumpSmartNameText(
        tester,
        name: 'Bruno Oliveira🎉',
        style: const TextStyle(fontSize: 16),
        maxWidth: 100,
      );

      final text = find.byType(Text);
      expect(text, findsOneWidget);
      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('Bruno'));
      // Should contain a period for abbreviation
      expect(widget.data, contains('.'));
    });

    testWidgets('handles name with only emoji', (tester) async {
      await pumpSmartNameText(
        tester,
        name: '🎉 🎊 🎈',
        style: const TextStyle(fontSize: 16),
        maxWidth: 100,
      );

      final text = find.byType(Text);
      expect(text, findsOneWidget);
      final widget = tester.widget<Text>(text);
      expect(widget.data, isNotEmpty);
    });

    testWidgets('respects custom abbreviationThreshold', (
      tester,
    ) async {
      await pumpSmartNameText(
        tester,
        name: 'Short',
        style: const TextStyle(fontSize: 16),
        abbreviationThreshold: 20.0,
        maxWidth: 200,
      );

      // With a large threshold, the text should be rendered
      final text = find.byType(Text);
      expect(text, findsOneWidget);
    });

    testWidgets('applies correct text alignment', (tester) async {
      await pumpSmartNameText(
        tester,
        name: 'John Doe',
        style: const TextStyle(fontSize: 16),
        textAlign: TextAlign.left,
        maxWidth: 200,
      );

      final text = find.byType(Text);
      expect(text, findsOneWidget);
      final widget = tester.widget<Text>(text);
      expect(widget.textAlign, equals(TextAlign.left));
    });

    testWidgets('applies correct text alignment center', (
      tester,
    ) async {
      await pumpSmartNameText(
        tester,
        name: 'John Doe',
        style: const TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
        maxWidth: 200,
      );

      final text = find.byType(Text);
      expect(text, findsOneWidget);
      final widget = tester.widget<Text>(text);
      expect(widget.textAlign, equals(TextAlign.center));
    });

    testWidgets('sets maxLines to 1 and ellipsis overflow', (
      tester,
    ) async {
      await pumpSmartNameText(
        tester,
        name: 'John Doe',
        style: const TextStyle(fontSize: 16),
        maxWidth: 200,
      );

      final text = find.byType(Text);
      expect(text, findsOneWidget);
      final widget = tester.widget<Text>(text);
      expect(widget.maxLines, equals(1));
      expect(widget.overflow, equals(TextOverflow.ellipsis));
    });

    testWidgets('applies custom style', (tester) async {
      const customStyle = TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
      );

      await pumpSmartNameText(
        tester,
        name: 'John',
        style: customStyle,
        maxWidth: 200,
      );

      final text = find.byType(Text);
      expect(text, findsOneWidget);
      final widget = tester.widget<Text>(text);
      expect(widget.style, equals(customStyle));
    });

    testWidgets('handles very narrow width', (tester) async {
      await pumpSmartNameText(
        tester,
        name: 'Elizabeth Alexandra Mary',
        style: const TextStyle(fontSize: 16),
        maxWidth: 30,
      );

      final text = find.byType(Text);
      expect(text, findsOneWidget);
      final widget = tester.widget<Text>(text);
      expect(widget.data, isNotEmpty);
    });

    testWidgets('handles empty-like strings', (tester) async {
      await pumpSmartNameText(
        tester,
        name: '   ',
        style: const TextStyle(fontSize: 16),
        maxWidth: 100,
      );

      final text = find.byType(Text);
      expect(text, findsOneWidget);
    });

    testWidgets('abbreviation uses first char of last word', (
      tester,
    ) async {
      // Test multiple examples to verify abbreviation logic
      final testCases = [
        ('John Smith', 'Smith'),
        ('Alice Bob Charlie', 'Charlie'),
        ('Marie Antoinette', 'Antoinette'),
      ];

      for (final (fullName, lastName) in testCases) {
        await pumpSmartNameText(
          tester,
          name: fullName,
          style: const TextStyle(fontSize: 16),
          maxWidth: 60, // Force abbreviation
        );

        final text = find.byType(Text);
        final widget = tester.widget<Text>(text);
        final firstChar = lastName.characters.first;
        expect(widget.data, contains(firstChar.toUpperCase()));
        expect(widget.data, contains('.'));

        // Clean up for next iteration
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('handles special unicode characters', (
      tester,
    ) async {
      await pumpSmartNameText(
        tester,
        name: 'José García',
        style: const TextStyle(fontSize: 16),
        maxWidth: 200,
      );

      final text = find.byType(Text);
      expect(text, findsOneWidget);
      final widget = tester.widget<Text>(text);
      expect(widget.data, contains('José'));
      expect(widget.data, contains('García'));
    });

    testWidgets('handles complex emoji sequences', (tester) async {
      // Family emoji sequence
      await pumpSmartNameText(
        tester,
        name: 'Family 👨‍👩‍👧‍👦',
        style: const TextStyle(fontSize: 16),
        maxWidth: 150,
      );

      final text = find.byType(Text);
      expect(text, findsOneWidget);
      final widget = tester.widget<Text>(text);
      expect(widget.data, isNotEmpty);
    });

    testWidgets('no null style crashes widget', (tester) async {
      await pumpSmartNameText(
        tester,
        name: 'John Doe',
        style: null,
        maxWidth: 200,
      );

      final text = find.byType(Text);
      expect(text, findsOneWidget);
      expect(find.byType(SmartNameText), findsOneWidget);
    });
  });
}
