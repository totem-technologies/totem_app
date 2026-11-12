import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/widgets/adaptive_call_layout.dart';

void main() {
  testWidgets(
    'balances six participants and falls back to one row at short heights',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<List<Rect>> layout(Size size) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: AdaptiveCallLayout(
                  participants: [
                    for (var i = 0; i < 6; i++)
                      ColoredBox(
                        key: ValueKey(i),
                        color: const Color(0xff000000),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        final bounds = tester.getRect(find.byType(AdaptiveCallLayout));
        final tiles = [
          for (var i = 0; i < 6; i++)
            tester.getRect(
              find.byWidgetPredicate(
                (widget) => widget is ColoredBox && widget.key == ValueKey(i),
              ),
            ),
        ];
        for (var i = 0; i < tiles.length; i++) {
          final tile = tiles[i];
          check(tile.width > 0 && tile.height > 0).isTrue();
          check(
            tile.left >= bounds.left &&
                tile.top >= bounds.top &&
                tile.right <= bounds.right &&
                tile.bottom <= bounds.bottom,
          ).isTrue();
          for (final other in tiles.skip(i + 1)) {
            check(tile.overlaps(other)).isFalse();
          }
        }
        return tiles;
      }

      final gallery = await layout(const Size(1392, 520));
      check(gallery.map((rect) => rect.left).toSet().length).equals(3);
      final rows = <double, int>{};
      for (final rect in gallery) {
        rows.update(rect.top, (count) => count + 1, ifAbsent: () => 1);
      }
      check(rows.length).equals(2);
      check(rows.values.toList()).deepEquals([3, 3]);

      final short = await layout(const Size(1392, 140));
      check(short.map((rect) => rect.top).toSet().length).equals(1);
      check(short.map((rect) => rect.left).toSet().length).equals(6);
    },
  );
}
