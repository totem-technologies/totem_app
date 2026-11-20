import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/session_side_panel.dart';

const _content = Key('panel-content');
const _video = Key('video');
const _screen = Size(1600, 1000);

void main() {
  void useScreen(WidgetTester tester, [Size screen = _screen]) {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget dockedHost({
    required bool open,
    TextDirection textDirection = TextDirection.ltr,
    bool disableAnimations = false,
    Widget content = const SizedBox.expand(key: _content),
    VoidCallback? onDismiss,
    VoidCallback? onVideoTap,
    FocusNode? toggleFocus,
  }) {
    return MaterialApp(
      builder: (context, navigator) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: navigator!,
      ),
      home: Directionality(
        textDirection: textDirection,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onVideoTap,
                child: const SizedBox.expand(key: _video),
              ),
            ),
            if (toggleFocus != null)
              Positioned(
                left: 0,
                top: 0,
                child: TextButton(
                  focusNode: toggleFocus,
                  onPressed: () {},
                  child: const Text('toggle'),
                ),
              ),
            // Like the room, the child is dropped once the panel closes.
            DockedSessionSidePanel(
              open: open,
              onDismiss: onDismiss,
              child: open ? content : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> openDrawer(
    WidgetTester tester, {
    TextDirection textDirection = TextDirection.ltr,
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        // Above the navigator, so the pushed route sees them too.
        builder: (context, navigator) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: Directionality(
            textDirection: textDirection,
            child: navigator!,
          ),
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSessionSidePanelDrawer(
              context,
              settings: const RouteSettings(name: 'drawer'),
              child: const SizedBox.expand(key: _content),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
  }

  final cardRect = Rect.fromLTRB(
    _screen.width - sessionSidePanelInset - sessionSidePanelWidth,
    sessionSidePanelInset,
    _screen.width - sessionSidePanelInset,
    _screen.height - sessionSidePanelInset,
  );

  final rtlCardRect = Rect.fromLTRB(
    sessionSidePanelInset,
    sessionSidePanelInset,
    sessionSidePanelInset + sessionSidePanelWidth,
    _screen.height - sessionSidePanelInset,
  );

  double opacityOf(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find
            .ancestor(
              of: find.byKey(_content),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;

  testWidgets('floats the card over the room, inset from its edges', (
    tester,
  ) async {
    useScreen(tester);
    await tester.pumpWidget(dockedHost(open: true));

    check(tester.getRect(find.byKey(_content))).equals(cardRect);
    // Nothing makes room for the panel: the video keeps the full width.
    check(tester.getSize(find.byKey(_video))).equals(_screen);
  });

  for (final direction in TextDirection.values) {
    testWidgets('slides and fades the card in from the trailing edge in '
        '${direction.name}', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(
        dockedHost(open: false, textDirection: direction),
      );
      await tester.pumpWidget(dockedHost(open: true, textDirection: direction));
      await tester.pump(sessionSidePanelDuration ~/ 2);

      final settled = direction == TextDirection.ltr ? cardRect : rtlCardRect;
      final panel = tester.getRect(find.byKey(_content));
      check(panel.size).equals(settled.size);
      if (direction == TextDirection.ltr) {
        check(panel.left)
          ..isGreaterThan(settled.left)
          ..isLessThan(_screen.width);
      } else {
        check(panel.right)
          ..isLessThan(settled.right)
          ..isGreaterThan(0);
      }
      check(opacityOf(tester))
        ..isGreaterThan(0)
        ..isLessThan(1);
      check(tester.getSize(find.byKey(_video))).equals(_screen);

      await tester.pumpAndSettle();
      check(tester.getRect(find.byKey(_content))).equals(settled);
      check(opacityOf(tester)).equals(1);
    });
  }

  testWidgets('ignores input while closing and removes the card once closed', (
    tester,
  ) async {
    useScreen(tester);
    var videoTaps = 0;
    await tester.pumpWidget(
      dockedHost(open: true, onVideoTap: () => videoTaps++),
    );
    await tester.pumpWidget(
      dockedHost(open: false, onVideoTap: () => videoTaps++),
    );
    await tester.pump(sessionSidePanelReverseDuration ~/ 4);

    // The last panel stays on screen while it slides out, but taps on it
    // already reach the room.
    check(find.byKey(_content).evaluate()).length.equals(1);
    await tester.tapAt(cardRect.center);
    check(videoTaps).equals(1);

    await tester.pumpAndSettle();
    check(find.byKey(_content).evaluate()).isEmpty();
    check(tester.getSize(find.byKey(_video))).equals(_screen);
  });

  testWidgets('passes taps outside the card through to the room', (
    tester,
  ) async {
    useScreen(tester);
    var videoTaps = 0;
    var panelTaps = 0;
    await tester.pumpWidget(
      dockedHost(
        open: true,
        onVideoTap: () => videoTaps++,
        content: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => panelTaps++,
          child: const SizedBox.expand(key: _content),
        ),
      ),
    );

    // The trailing, top and bottom gaps, and the room beside the card.
    for (final point in [
      Offset(_screen.width - sessionSidePanelInset / 2, _screen.height / 2),
      Offset(cardRect.center.dx, sessionSidePanelInset / 2),
      Offset(cardRect.center.dx, _screen.height - sessionSidePanelInset / 2),
      Offset(cardRect.left - 40, _screen.height / 2),
    ]) {
      await tester.tapAt(point);
    }
    check(videoTaps).equals(4);
    check(panelTaps).equals(0);

    await tester.tapAt(cardRect.center);
    check(panelTaps).equals(1);
    check(videoTaps).equals(4);
  });

  testWidgets('dismisses on Escape from inside the panel, even a text field', (
    tester,
  ) async {
    useScreen(tester);
    var dismissals = 0;
    await tester.pumpWidget(
      dockedHost(
        open: true,
        onDismiss: () => dismissals++,
        content: const Material(child: TextField(autofocus: true)),
      ),
    );
    await tester.pump();
    check(tester.testTextInput.isVisible).isTrue();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    check(dismissals).equals(1);
  });

  testWidgets('returns focus to what held it before the panel opened', (
    tester,
  ) async {
    useScreen(tester);
    final toggle = FocusNode(debugLabel: 'toggle');
    addTearDown(toggle.dispose);
    final field = FocusNode(debugLabel: 'field');
    addTearDown(field.dispose);
    Widget host({required bool open}) => dockedHost(
      open: open,
      toggleFocus: toggle,
      content: Material(child: TextField(focusNode: field)),
    );

    await tester.pumpWidget(host(open: false));
    toggle.requestFocus();
    await tester.pump();
    await tester.pumpWidget(host(open: true));
    await tester.pumpAndSettle();
    field.requestFocus();
    await tester.pump();
    check(field.hasFocus).isTrue();

    await tester.pumpWidget(host(open: false));
    await tester.pump();
    check(field.hasFocus).isFalse();
    check(toggle.hasFocus).isTrue();
    await tester.pumpAndSettle();
    check(toggle.hasFocus).isTrue();
  });

  testWidgets('opens the drawer as the inset card', (tester) async {
    useScreen(tester);
    await openDrawer(tester);
    await tester.pumpAndSettle();

    check(tester.getRect(find.byKey(_content))).equals(cardRect);
  });

  testWidgets('floats the drawer with the inset in a small window', (
    tester,
  ) async {
    const window = Size(700, 900);
    useScreen(tester, window);
    await openDrawer(tester);
    await tester.pump(const Duration(milliseconds: 1));
    check(opacityOf(tester)).isLessThan(1);

    await tester.pumpAndSettle();
    check(tester.getRect(find.byKey(_content))).equals(
      Rect.fromLTRB(
        window.width - sessionSidePanelInset - sessionSidePanelWidth,
        sessionSidePanelInset,
        window.width - sessionSidePanelInset,
        window.height - sessionSidePanelInset,
      ),
    );
    check(opacityOf(tester)).equals(1);
  });

  testWidgets('keeps the inset on both sides when narrower than the panel', (
    tester,
  ) async {
    const window = Size(400, 900);
    useScreen(tester, window);
    await openDrawer(tester);
    await tester.pumpAndSettle();

    check(tester.getRect(find.byKey(_content))).equals(
      Rect.fromLTRB(
        sessionSidePanelInset,
        sessionSidePanelInset,
        window.width - sessionSidePanelInset,
        window.height - sessionSidePanelInset,
      ),
    );
  });

  testWidgets('slides the RTL drawer in from the leading edge', (tester) async {
    useScreen(tester);
    await openDrawer(tester, textDirection: TextDirection.rtl);
    await tester.pump(const Duration(milliseconds: 1));

    check(
      tester.getRect(find.byKey(_content)).right,
    ).isLessThan(sessionSidePanelWidth);

    await tester.pumpAndSettle();
    check(
      tester.getRect(find.byKey(_content)).left,
    ).equals(sessionSidePanelInset);
  });

  testWidgets('opens at its final rect at once when animations are off', (
    tester,
  ) async {
    useScreen(tester);
    await tester.pumpWidget(dockedHost(open: false, disableAnimations: true));
    await tester.pumpWidget(dockedHost(open: true, disableAnimations: true));

    check(tester.getRect(find.byKey(_content))).equals(cardRect);
    check(opacityOf(tester)).equals(1);

    await tester.pumpWidget(dockedHost(open: false, disableAnimations: true));
    await tester.pump();
    check(find.byKey(_content).evaluate()).isEmpty();

    await tester.pumpWidget(Container());
    await openDrawer(tester, disableAnimations: true);

    check(tester.getRect(find.byKey(_content))).equals(cardRect);
  });
}
