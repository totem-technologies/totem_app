import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/participant_overlay_metrics.dart';

void main() {
  Future<void> setViewSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<(ParticipantOverlayMetrics grid, ParticipantOverlayMetrics featured)>
  metricsFor(WidgetTester tester, Size size) async {
    await setViewSize(tester, size);

    late ParticipantOverlayMetrics grid;
    late ParticipantOverlayMetrics featured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            grid = ParticipantOverlayMetrics.of(context);
            featured = ParticipantOverlayMetrics.featuredOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return (grid, featured);
  }

  testWidgets('is compact at the 600px phone breakpoint', (tester) async {
    final metrics = await metricsFor(tester, const Size(800, 600));
    expect(metrics.$1, ParticipantOverlayMetrics.compact);
    expect(metrics.$2, ParticipantOverlayMetrics.compactFeatured);
  });

  testWidgets('is compact in phone portrait', (tester) async {
    final metrics = await metricsFor(tester, const Size(400, 800));
    expect(metrics.$1, ParticipantOverlayMetrics.compact);
    expect(metrics.$2, ParticipantOverlayMetrics.compactFeatured);
  });

  testWidgets('is comfortable on tablet portrait (mediumSmall)', (
    tester,
  ) async {
    final metrics = await metricsFor(tester, const Size(700, 1000));
    expect(metrics.$1, ParticipantOverlayMetrics.comfortable);
    expect(metrics.$2, ParticipantOverlayMetrics.comfortable);
  });

  testWidgets('is comfortable above 600px shortest side', (tester) async {
    final metrics = await metricsFor(tester, const Size(1200, 900));
    expect(metrics.$1, ParticipantOverlayMetrics.comfortable);
    expect(metrics.$2, ParticipantOverlayMetrics.comfortable);
  });
}
