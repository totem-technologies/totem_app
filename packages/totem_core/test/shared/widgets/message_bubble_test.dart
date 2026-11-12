import 'package:checks/checks.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/widgets/chat/message_bubble.dart';
// The launcher platform is a transitive dependency used only for this test fake.
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/link.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FakeUrlLauncher extends UrlLauncherPlatform {
  final launches = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launches.add(url);
    return true;
  }
}

Iterable<TextSpan> _textSpans(InlineSpan span) sync* {
  if (span is! TextSpan) return;
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    yield* _textSpans(child);
  }
}

void main() {
  testWidgets('lays out a content-width bubble with trailing timestamp', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: MessageBubble(
              text: 'Hello',
              timestamp: '10:25 AM',
              isOwn: true,
            ),
          ),
        ),
      ),
    );

    final bubble = find.ancestor(
      of: find.text('Hello'),
      matching: find.byType(DecoratedBox),
    );

    check(tester.widgetList(find.byType(IntrinsicWidth))).length.equals(1);
    check(tester.getSize(find.byType(MessageBubble)).width).equals(400);
    check(tester.getSize(bubble).width).isLessThan(336);
    check(
      tester.getTopRight(find.text('10:25 AM')).dx,
    ).isCloseTo(tester.getTopRight(bubble).dx - 14, 0.1);
  });

  testWidgets(
    'trailing punctuation remains outside links and taps launch their targets',
    (
      tester,
    ) async {
      final originalLauncher = UrlLauncherPlatform.instance;
      final launcher = _FakeUrlLauncher();
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = originalLauncher);

      const text =
          'https://example.com/path?q=one, hello@example.com; +1 (415) 555-2671!';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              text: text,
              timestamp: '10:25 AM',
              isOwn: false,
            ),
          ),
        ),
      );

      final message = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      final spans = _textSpans(message.textSpan!).toList();
      check(spans.map((span) => span.text ?? '').join()).equals(text);
      check(
        spans
            .where((span) => span.recognizer is TapGestureRecognizer)
            .map((span) => span.text)
            .toList(),
      ).deepEquals([
        'https://example.com/path?q=one',
        'hello@example.com',
        '+1 (415) 555-2671',
      ]);

      final editable = tester
          .state<EditableTextState>(
            find.byType(EditableText),
          )
          .renderEditable;
      for (final link in [
        'https://example.com/path?q=one',
        'hello@example.com',
        '+1 (415) 555-2671',
      ]) {
        final offset = text.indexOf(link) + 2;
        final caret = editable.getLocalRectForCaret(
          TextPosition(offset: offset),
        );
        await tester.tapAt(editable.localToGlobal(caret.center));
        await tester.pump();
      }
      check(launcher.launches).deepEquals([
        'https://example.com/path?q=one',
        'mailto:hello@example.com',
        'tel:+14155552671',
      ]);
    },
  );

  for (final scenario in [
    (text: '(https://example.com)', url: 'https://example.com'),
    (text: '[https://example.com]', url: 'https://example.com'),
    (text: '"https://example.com"', url: 'https://example.com'),
    (text: "'https://example.com'", url: 'https://example.com'),
    (
      text: 'https://example.com/wiki/Foo_(bar)',
      url: 'https://example.com/wiki/Foo_(bar)',
    ),
    (
      text: '(https://example.com/wiki/Foo_(bar)),!',
      url: 'https://example.com/wiki/Foo_(bar)',
    ),
  ]) {
    testWidgets('opens the intended URL in ${scenario.text}', (tester) async {
      final originalLauncher = UrlLauncherPlatform.instance;
      final launcher = _FakeUrlLauncher();
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = originalLauncher);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              text: scenario.text,
              timestamp: '10:25 AM',
              isOwn: false,
            ),
          ),
        ),
      );
      final message = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      check(
        _textSpans(message.textSpan!).map((span) => span.text ?? '').join(),
      ).equals(scenario.text);
      final editable = tester
          .state<EditableTextState>(find.byType(EditableText))
          .renderEditable;
      final offset = scenario.text.indexOf('https://') + 3;
      final caret = editable.getLocalRectForCaret(TextPosition(offset: offset));
      await tester.tapAt(editable.localToGlobal(caret.center));
      await tester.pump();
      check(launcher.launches).deepEquals([scenario.url]);
    });
  }

  testWidgets('mouse cursor distinguishes links from selectable plain text', (
    tester,
  ) async {
    const text = 'Read https://example.com now';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessageBubble(text: text, timestamp: '10:25 AM', isOwn: false),
        ),
      ),
    );
    final editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);

    Future<void> hoverAt(int offset) async {
      final caret = editable.getLocalRectForCaret(TextPosition(offset: offset));
      await mouse.moveTo(editable.localToGlobal(caret.center));
      await tester.pump();
    }

    await hoverAt(2);
    check(
      tester.binding.mouseTracker.debugDeviceActiveCursor(1),
    ).equals(SystemMouseCursors.text);
    await hoverAt(text.indexOf('https://') + 3);
    check(
      tester.binding.mouseTracker.debugDeviceActiveCursor(1),
    ).equals(SystemMouseCursors.click);
    await hoverAt(text.indexOf('now') + 1);
    check(
      tester.binding.mouseTracker.debugDeviceActiveCursor(1),
    ).equals(SystemMouseCursors.text);
  });

  testWidgets('highlights URLs, emails, and phone numbers as actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            text:
                'Visit https://example.com, email hello@example.com, or call +1 (415) 555-2671.',
            timestamp: '10:25 AM',
            isOwn: false,
          ),
        ),
      ),
    );

    final messageText = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    final actionableSpans = _textSpans(
      messageText.textSpan!,
    ).where((span) => span.recognizer is TapGestureRecognizer).toList();

    check(
      actionableSpans.map((span) => span.text),
    ).contains('https://example.com');
    check(
      actionableSpans.map((span) => span.text),
    ).contains('hello@example.com');
    check(
      actionableSpans.map((span) => span.text),
    ).contains('+1 (415) 555-2671');
    for (final span in actionableSpans) {
      check(span.style?.decoration).equals(TextDecoration.underline);
    }
  });
}
