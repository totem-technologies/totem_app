import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/widgets/transition_card.dart';

Future<void> _loadMontserrat() async {
  final fontsDir = Directory(
    '${Platform.environment['HOME']}/Desktop/projects/Totem/totem_app/packages/totem_widgetbook/assets/fonts',
  );
  Future<ByteData> load(String name) async {
    final bytes = await File('${fontsDir.path}/$name').readAsBytes();
    return ByteData.sublistView(bytes);
  }

  final loader = FontLoader('Montserrat')
    ..addFont(load('Montserrat-Regular.ttf'))
    ..addFont(load('Montserrat-Medium.ttf'))
    ..addFont(load('Montserrat-SemiBold.ttf'))
    ..addFont(load('Montserrat-Bold.ttf'));
  await loader.load();
}

void main() {
  setUpAll(_loadMontserrat);

  Future<void> pumpCard(
    WidgetTester tester, {
    required Size size,
    required TargetPlatform platform,
    required Widget card,
    required Color scaffoldColor,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          backgroundColor: scaffoldColor,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: card,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets(
    'desktop default pass and receive',
    (tester) async {
      // Typical laptop / default desktop web viewport.
      const size = Size(1440, 900);

      await pumpCard(
        tester,
        size: size,
        platform: TargetPlatform.macOS,
        scaffoldColor: AppTheme.slate,
        card: PassTransitionCard(onActionPressed: () async => true),
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/desktop_pass_dock.png'),
      );

      await pumpCard(
        tester,
        size: size,
        platform: TargetPlatform.macOS,
        scaffoldColor: AppTheme.slate,
        card: ReceiveTransitionCard(onActionPressed: () async => true),
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/desktop_receive_dock.png'),
      );
    },
    experimentalLeakTesting: LeakTesting.settings.withIgnored(
      classes: <String>['TextPainter'],
    ),
  );

  testWidgets(
    'mobile web pass and receive',
    (tester) async {
      // iPhone-class mobile web viewport (portrait).
      const size = Size(390, 844);

      await pumpCard(
        tester,
        size: size,
        platform: TargetPlatform.iOS,
        scaffoldColor: AppTheme.cream,
        card: PassTransitionCard(onActionPressed: () async => true),
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/mobile_web_pass.png'),
      );

      await pumpCard(
        tester,
        size: size,
        platform: TargetPlatform.iOS,
        // Receive on phone uses the white card treatment.
        scaffoldColor: AppTheme.cream,
        card: ReceiveTransitionCard(onActionPressed: () async => true),
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/mobile_web_receive.png'),
      );
    },
    experimentalLeakTesting: LeakTesting.settings.withIgnored(
      classes: <String>['TextPainter'],
    ),
  );
}
