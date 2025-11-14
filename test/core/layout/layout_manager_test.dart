import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/core/layout/layout.dart';

void main() {
  group('LayoutInfo', () {
    testWidgets('detects mobile portrait correctly', (tester) async {
      late LayoutInfo layoutInfo;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
          ),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                layoutInfo = LayoutInfo.fromContext(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(layoutInfo.deviceType, DeviceType.mobilePortrait);
      expect(layoutInfo.isMobile, isTrue);
      expect(layoutInfo.isPortrait, isTrue);
      expect(layoutInfo.isLandscape, isFalse);
      expect(layoutInfo.orientation, Orientation.portrait);
    });

    testWidgets('detects mobile landscape correctly', (tester) async {
      late LayoutInfo layoutInfo;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(600, 300),
          ),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                layoutInfo = LayoutInfo.fromContext(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(layoutInfo.deviceType, DeviceType.mobileLandscape);
      expect(layoutInfo.isMobile, isTrue);
      expect(layoutInfo.isPortrait, isFalse);
      expect(layoutInfo.isLandscape, isTrue);
      expect(layoutInfo.orientation, Orientation.landscape);
    });

    testWidgets('provides correct padding values', (tester) async {
      late LayoutInfo layoutInfo;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
          ),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                layoutInfo = LayoutInfo.fromContext(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(layoutInfo.horizontalPadding, 16.0);
      expect(layoutInfo.verticalPadding, 16.0);
    });

    testWidgets('provides correct grid columns for portrait', (tester) async {
      late LayoutInfo layoutInfo;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
          ),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                layoutInfo = LayoutInfo.fromContext(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(layoutInfo.gridColumns, 1);
    });

    testWidgets('provides correct grid columns for landscape', (tester) async {
      late LayoutInfo layoutInfo;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(600, 300),
          ),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                layoutInfo = LayoutInfo.fromContext(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(layoutInfo.gridColumns, 2);
    });
  });

  group('ResponsiveLayoutManager', () {
    testWidgets('provides LayoutInfo to builder', (tester) async {
      LayoutInfo? receivedLayoutInfo;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
          ),
          child: MaterialApp(
            home: ResponsiveLayoutManager(
              builder: (context, layoutInfo) {
                receivedLayoutInfo = layoutInfo;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(receivedLayoutInfo, isNotNull);
      expect(receivedLayoutInfo!.deviceType, DeviceType.mobilePortrait);
    });

    testWidgets('updates layout when orientation changes', (tester) async {
      final layoutInfos = <DeviceType>[];

      Widget buildWithSize(Size size) {
        return MediaQuery(
          data: MediaQueryData(
            size: size,
          ),
          child: MaterialApp(
            home: ResponsiveLayoutManager(
              builder: (context, layoutInfo) {
                layoutInfos.add(layoutInfo.deviceType);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }

      // Start with portrait
      await tester.pumpWidget(buildWithSize(const Size(400, 800)));
      expect(layoutInfos.last, DeviceType.mobilePortrait);

      // Change to landscape
      await tester.pumpWidget(buildWithSize(const Size(600, 300)));
      await tester.pump();

      expect(layoutInfos.last, DeviceType.mobileLandscape);
    });

    testWidgets('provides LayoutInfo via context extension', (tester) async {
      LayoutInfo? layoutInfo;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
          ),
          child: MaterialApp(
            home: ResponsiveLayoutManager(
              builder: (context, _) {
                return Builder(
                  builder: (innerContext) {
                    layoutInfo = innerContext.layoutInfo;
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(layoutInfo, isNotNull);
      expect(layoutInfo!.deviceType, DeviceType.mobilePortrait);
    });
  });

  group('AdaptiveLayout', () {
    testWidgets('shows mobilePortrait widget in portrait mode', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(
            size: Size(400, 800),
          ),
          child: MaterialApp(
            home: AdaptiveLayout(
              mobilePortrait: Text('Portrait'),
              mobileLandscape: Text('Landscape'),
            ),
          ),
        ),
      );

      expect(find.text('Portrait'), findsOneWidget);
      expect(find.text('Landscape'), findsNothing);
    });

    testWidgets('shows mobileLandscape widget in landscape mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(
            size: Size(800, 400),
          ),
          child: MaterialApp(
            home: AdaptiveLayout(
              mobilePortrait: Text('Portrait'),
              mobileLandscape: Text('Landscape'),
            ),
          ),
        ),
      );

      expect(find.text('Portrait'), findsNothing);
      expect(find.text('Landscape'), findsOneWidget);
    });

    testWidgets('falls back to mobilePortrait when mobileLandscape is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(
            size: Size(800, 400),
          ),
          child: MaterialApp(
            home: AdaptiveLayout(
              mobilePortrait: Text('Portrait'),
            ),
          ),
        ),
      );

      expect(find.text('Portrait'), findsOneWidget);
    });
  });

  group('ResponsiveContainer', () {
    testWidgets('applies padding from LayoutInfo', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
          ),
          child: MaterialApp(
            home: ResponsiveLayoutManager(
              builder: (context, _) {
                return const ResponsiveContainer(
                  child: Text('Content'),
                );
              },
            ),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(ResponsiveContainer),
              matching: find.byType(Padding),
            )
            .first,
      );

      expect(
        padding.padding,
        const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      );
    });

    testWidgets('applies custom padding when provided', (tester) async {
      const customPadding = EdgeInsets.all(24);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
          ),
          child: MaterialApp(
            home: ResponsiveLayoutManager(
              builder: (context, _) {
                return const ResponsiveContainer(
                  padding: customPadding,
                  child: Text('Content'),
                );
              },
            ),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(ResponsiveContainer),
              matching: find.byType(Padding),
            )
            .first,
      );

      expect(padding.padding, customPadding);
    });
  });

  group('BreakpointConfig', () {
    test('provides default breakpoints', () {
      const config = BreakpointConfig.defaultConfig;

      expect(config.mobileMaxWidth, 600);
      expect(config.tabletMaxWidth, 900);
      expect(config.desktopMinWidth, 1025);
    });

    testWidgets('custom breakpoints affect device type detection', (
      tester,
    ) async {
      late LayoutInfo layoutInfo;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(650, 900),
          ),
          child: MaterialApp(
            home: ResponsiveLayoutManager(
              breakpoints: const BreakpointConfig(
                mobileMaxWidth: 700, // Custom breakpoint
              ),
              builder: (context, info) {
                layoutInfo = info;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      // With custom breakpoint of 700, a 650px width should be mobile
      expect(layoutInfo.isMobile, isTrue);
    });
  });
}
