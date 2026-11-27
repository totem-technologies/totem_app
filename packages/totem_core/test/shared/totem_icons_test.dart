import 'dart:ui' as ui;

import 'package:checks/checks.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/totem_icons.dart';

void main() {
  test(
    'the forward arrow SVG is the back arrow mirrored in the same viewBox',
    () {
      const viewBox = 'viewBox="0 0 16 16"';
      check(TotemIcons.arrowBack).contains(viewBox);
      check(TotemIcons.arrowForward).contains(viewBox);
      check(TotemIcons.arrowBack).contains('translate(3 0)');
      check(TotemIcons.arrowForward).contains('translate(13 0) scale(-1 1)');
      check(
        TotemIcons.arrowForward,
      ).not((it) => it.contains('viewBox="0 0 22 22"'));

      final backPath = _pathData(TotemIcons.arrowBack);
      final forwardPath = _pathData(TotemIcons.arrowForward);
      check(backPath).isNotNull();
      check(forwardPath).equals(backPath);
    },
  );

  testWidgets(
    'the forward arrow glyph is a centered mirror of the back arrow',
    (tester) async {
      const backKey = ValueKey('back');
      const forwardKey = ValueKey('forward');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Color(0xFF000000),
            body: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  key: backKey,
                  child: TotemIcon(
                    TotemIcons.arrowBack,
                    size: 64,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
                RepaintBoundary(
                  key: forwardKey,
                  child: TotemIcon(
                    TotemIcons.arrowForward,
                    size: 64,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final back = await tester.runAsync(
        () => _inkBounds(tester, find.byKey(backKey)),
      );
      final forward = await tester.runAsync(
        () => _inkBounds(tester, find.byKey(forwardKey)),
      );

      // The old forward glyph was ~58% of the box tall and sat against the
      // right edge. A mirrored, unclipped chevron fills most of the box
      // and stays near the centre.
      check(back).isNotNull();
      check(forward).isNotNull();
      final backBounds = back!;
      final forwardBounds = forward!;
      check(backBounds.height / backBounds.imageHeight).isGreaterThan(0.8);
      check(
        forwardBounds.height / forwardBounds.imageHeight,
      ).isGreaterThan(0.8);
      check((forwardBounds.width - backBounds.width).abs()).isLessThan(3);
      check((forwardBounds.height - backBounds.height).abs()).isLessThan(3);
      check(
        (forwardBounds.centerX + backBounds.centerX - backBounds.imageWidth)
            .abs(),
      ).isLessThan(3);
      check((forwardBounds.centerY - backBounds.centerY).abs()).isLessThan(3);
    },
  );
}

String? _pathData(String svg) {
  final match = RegExp(r'\bd="([^"]+)"').firstMatch(svg);
  return match?.group(1);
}

Future<
  ({
    int width,
    int height,
    double centerX,
    double centerY,
    int imageWidth,
    int imageHeight,
  })
>
_inkBounds(WidgetTester tester, Finder finder) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
  final image = await boundary.toImage(pixelRatio: 4);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = data!.buffer.asUint8List();
  final imageWidth = image.width;
  final imageHeight = image.height;
  var minX = imageWidth;
  var minY = imageHeight;
  var maxX = -1;
  var maxY = -1;
  for (var y = 0; y < imageHeight; y++) {
    for (var x = 0; x < imageWidth; x++) {
      final i = (y * imageWidth + x) * 4;
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];
      final a = bytes[i + 3];
      if (a > 128 && r > 200 && g > 200 && b > 200) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  check(maxX).isGreaterThan(-1);
  return (
    width: maxX - minX + 1,
    height: maxY - minY + 1,
    centerX: (minX + maxX) / 2,
    centerY: (minY + maxY) / 2,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );
}
