import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/participant_overlay_metrics.dart';

void main() {
  test('clamps to compact chrome on a small grid tile', () {
    final metrics = ParticipantOverlayMetrics.forCard(const Size(160, 120));

    check(metrics.badgeSize).equals(20);
    check(metrics.iconSize).equals(16);
    check(metrics.badgePadding).equals(2);
    check(metrics.emojiFontSize).equals(10);
    check(metrics.cornerInset).equals(10);
  });

  test('clamps to the ceiling on a large card', () {
    final metrics = ParticipantOverlayMetrics.forCard(const Size(1200, 800));

    check(metrics.badgeSize).equals(28);
    check(metrics.iconSize).equals(22);
    check(metrics.badgePadding).equals(3);
    check(metrics.emojiFontSize).equals(14);
    check(metrics.cornerInset).equals(12);
  });

  test('scales between the floor and the ceiling on a mid-size card', () {
    final metrics = ParticipantOverlayMetrics.forCard(const Size(400, 260));

    // 260 * 0.09 = 23.4, rounded.
    check(metrics.badgeSize).equals(23);
    check(metrics.iconSize).equals(18);
    check(metrics.badgePadding).equals(2.5);
    check(metrics.emojiFontSize).equals(11.5);
    // 23 * 0.5 = 11.5, rounded so the badge never lands on a half pixel.
    check(metrics.cornerInset).equals(12);
  });

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
