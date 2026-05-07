import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

void main() {
  group('ViewportResolver', () {
    testWidgets('returns smallPortrait for portrait phones', (tester) async {
      ViewportKind? resolvedKind;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
            ),
            child: ViewportResolver(
              builder: (context, kind) {
                resolvedKind = kind;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolvedKind, ViewportKind.smallPortrait);
    });

    testWidgets('returns smallLandscape for landscape phones', (tester) async {
      ViewportKind? resolvedKind;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 400),
            ),
            child: ViewportResolver(
              builder: (context, kind) {
                resolvedKind = kind;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolvedKind, ViewportKind.smallLandscape);
    });

    testWidgets('returns mediumPlus for tablets in portrait', (tester) async {
      ViewportKind? resolvedKind;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 1024),
            ),
            child: ViewportResolver(
              builder: (context, kind) {
                resolvedKind = kind;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolvedKind, ViewportKind.mediumPlus);
    });

    testWidgets('returns mediumPlus for tablets in landscape', (tester) async {
      ViewportKind? resolvedKind;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(1024, 800),
            ),
            child: ViewportResolver(
              builder: (context, kind) {
                resolvedKind = kind;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolvedKind, ViewportKind.mediumPlus);
    });
  });
}
