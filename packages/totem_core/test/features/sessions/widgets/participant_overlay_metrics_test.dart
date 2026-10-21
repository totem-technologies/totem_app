import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/participant_overlay_metrics.dart';

void main() {
  test('scales off the shortest side, not the longest', () {
    check(
      ParticipantOverlayMetrics.forCard(const Size(1200, 260)),
    ).equals(ParticipantOverlayMetrics.forCard(const Size(260, 1200)));
  });

  test('keeps the badge padding invariant at every size', () {
    for (final shortestSide in [0.0, 80.0, 160.0, 260.0, 340.0, 900.0]) {
      final metrics = ParticipantOverlayMetrics.forCard(
        Size(shortestSide, shortestSide),
      );

      check(
        because: 'invariant broken at $shortestSide',
        metrics.badgeSize - 2 * metrics.badgePadding,
      ).equals(metrics.iconSize);
    }
  });

  test('clamps an unbounded card down to compact chrome', () {
    final compact = ParticipantOverlayMetrics.forCard(const Size(160, 120));

    // Without the isFinite guard this would clamp *up* to the ceiling.
    check(ParticipantOverlayMetrics.forCard(Size.infinite)).equals(compact);
    // An empty card needs no guard — the floor already covers it.
    check(ParticipantOverlayMetrics.forCard(Size.zero)).equals(compact);
  });
}
