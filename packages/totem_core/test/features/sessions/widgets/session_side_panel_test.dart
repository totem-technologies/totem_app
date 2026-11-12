import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/session_side_panel.dart';

const _content = Key('panel-content');
const _video = Key('video');
const _screen = Size(1600, 1000);

void main() {
  void useScreen(WidgetTester tester) {
    tester.view.physicalSize = _screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget dockedHost({
    required bool open,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    return MaterialApp(
      home: Directionality(
        textDirection: textDirection,
        child: Row(
          children: [
            const Expanded(child: SizedBox.expand(key: _video)),
            // Like the room, the child is dropped once the panel closes.
            DockedSessionSidePanel(
              open: open,
              child: open ? const SizedBox.expand(key: _content) : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> openDrawer(
    WidgetTester tester, {
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        // Above the navigator, so the pushed route sees it too.
        builder: (context, navigator) =>
            Directionality(textDirection: textDirection, child: navigator!),
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

  final trailingRect = Rect.fromLTRB(
    _screen.width - sessionSidePanelWidth,
    0,
    _screen.width,
    _screen.height,
  );

  testWidgets('docks the panel full height against the trailing edge', (
    tester,
  ) async {
    useScreen(tester);
    await tester.pumpWidget(dockedHost(open: true));

    check(tester.getRect(find.byKey(_content))).equals(trailingRect);
    check(
      tester.getSize(find.byKey(_video)).width,
    ).equals(_screen.width - sessionSidePanelWidth);
  });

  for (final direction in TextDirection.values) {
    testWidgets('slides the full-size panel along the video edge in '
        '${direction.name}', (tester) async {
      useScreen(tester);
      await tester.pumpWidget(
        dockedHost(open: false, textDirection: direction),
      );
      await tester.pumpWidget(dockedHost(open: true, textDirection: direction));
      await tester.pump(sessionSidePanelDuration ~/ 2);

      final video = tester.getRect(find.byKey(_video));
      final panel = tester.getRect(find.byKey(_content));
      check(video.width)
        ..isGreaterThan(_screen.width - sessionSidePanelWidth)
        ..isLessThan(_screen.width);
      check(panel.width).equals(sessionSidePanelWidth);
      if (direction == TextDirection.ltr) {
        check(panel.left).equals(video.right);
      } else {
        check(panel.right).equals(video.left);
      }

      await tester.pumpAndSettle();
      final settled = tester.getRect(find.byKey(_content));
      if (direction == TextDirection.ltr) {
        check(settled).equals(trailingRect);
      } else {
        check(
          settled,
        ).equals(Rect.fromLTRB(0, 0, sessionSidePanelWidth, _screen.height));
      }
    });
  }

  testWidgets('removes the panel once closed', (tester) async {
    useScreen(tester);
    await tester.pumpWidget(dockedHost(open: true));
    await tester.pumpWidget(dockedHost(open: false));
    await tester.pump(sessionSidePanelReverseDuration ~/ 2);

    // The last panel stays on screen while the rail slides out.
    check(find.byKey(_content).evaluate()).length.equals(1);
    check(
      tester.getSize(find.byKey(_video)).width,
    ).isGreaterThan(_screen.width - sessionSidePanelWidth);

    await tester.pumpAndSettle();
    check(find.byKey(_content).evaluate()).isEmpty();
    check(tester.getSize(find.byKey(_video)).width).equals(_screen.width);
  });

  testWidgets('opens the drawer full height against the trailing edge', (
    tester,
  ) async {
    useScreen(tester);
    await openDrawer(tester);
    await tester.pumpAndSettle();

    check(tester.getRect(find.byKey(_content))).equals(trailingRect);
  });

  testWidgets('slides the RTL drawer in from the leading edge', (tester) async {
    useScreen(tester);
    await openDrawer(tester, textDirection: TextDirection.rtl);
    await tester.pump(const Duration(milliseconds: 1));

    check(
      tester.getRect(find.byKey(_content)).right,
    ).isLessThan(sessionSidePanelWidth);

    await tester.pumpAndSettle();
    check(tester.getRect(find.byKey(_content)).left).equals(0);
  });
}
