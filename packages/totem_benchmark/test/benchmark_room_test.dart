import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_benchmark/benchmark_config.dart';
import 'package:totem_benchmark/benchmark_room.dart';
import 'package:totem_core/features/sessions/widgets/adaptive_call_layout.dart';
import 'package:totem_core/features/sessions/widgets/audio_visualizer_bars.dart';
import 'package:totem_core/features/sessions/widgets/participant_tile_surface.dart';

void main() {
  test('configuration rejects invalid workloads', () {
    check(BenchmarkConfig.fromQuery({}).participants).equals(6);
    for (final query in [
      {'participants': '0'},
      {'participants': '13'},
      {'notice': 'yes'},
      {'overlays': 'yes'},
      {'clip': 'typo'},
      {'video': 'typo'},
      {'unexpected': 'true'},
    ]) {
      check(() => BenchmarkConfig.fromQuery(query)).throws<Exception>();
    }
  });

  test('rendering controls round-trip through the query configuration', () {
    final config = BenchmarkConfig.fromQuery({
      'clip': 'none',
      'overlays': 'false',
    });
    check(config.clip).equals(TileClip.none);
    check(config.overlays).isFalse();
    check(
      BenchmarkConfig.fromQuery(
        config.toJson().map((key, value) => MapEntry(key, '$value')),
      ).toJson(),
    ).deepEquals(config.toJson());
  });

  testWidgets('joins and leaves preserve the remaining video widgets', (
    tester,
  ) async {
    Future<void> pump(int count) => tester.pumpWidget(
      MaterialApp(
        home: BenchmarkRoom(
          config: BenchmarkConfig(participants: count, notice: false),
          videoBuilder: (id, mode) =>
              ColoredBox(key: ValueKey('video-$id'), color: Colors.black),
        ),
      ),
    );
    await pump(2);
    final video = tester.element(find.byKey(const ValueKey('video-0')));
    await pump(6);
    check(find.byType(ParticipantTileSurface).evaluate()).length.equals(6);
    check(
      tester.element(find.byKey(const ValueKey('video-0'))),
    ).identicalTo(video);
    await pump(2);
    check(find.byType(ParticipantTileSurface).evaluate()).length.equals(2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('video widgets survive breakpoint-sized resizes', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    Future<Element> pumpAt(Size size) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveCallLayout(
            participants: [
              for (var id = 1; id < 4; id++)
                ColoredBox(key: ValueKey('video-$id'), color: Colors.black),
            ],
            speaker: const ColoredBox(
              key: ValueKey('video-0'),
              color: Colors.black,
            ),
          ),
        ),
      );
      return find.byKey(const ValueKey('video-0')).evaluate().first;
    }

    final initial = await pumpAt(const Size(390, 844));
    for (final size in [
      const Size(700, 900),
      const Size(1000, 800),
      const Size(1400, 900),
      const Size(390, 844),
    ]) {
      check(await pumpAt(size)).identicalTo(initial);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('waveform animates, freezes and releases its timer', (
    tester,
  ) async {
    Future<void> pump(WaveformMode mode) => tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: SyntheticWaveform(participant: 0, mode: mode),
          ),
        ),
      ),
    );
    List<double> samples() => tester
        .widget<BarsView>(find.byType(BarsView))
        .elements
        .map((item) => item.value)
        .toList();
    await pump(WaveformMode.animated);
    final initial = samples();
    await tester.pump(const Duration(milliseconds: 140));
    check(samples()).not((it) => it.deepEquals(initial));
    await pump(WaveformMode.frozen);
    final frozen = samples();
    await tester.pump(const Duration(seconds: 1));
    check(samples()).deepEquals(frozen);
    check(tester.binding.hasScheduledFrame).isFalse();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
