import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Adaptive turn-taking call layout — **layout engine only**.
///
/// Arranges an optional featured *speaker* tile plus a grid of *participant*
/// tiles, keeping every tile at a fixed aspect ratio (4:5 by default) and
/// re-fitting the grid to the available space and the number of tiles.
///
/// Behaviour mirrors the web prototype:
///   • Wide (>= [mobileBreakpoint]) → "row": speaker on the left takes the
///     lion's share of the width, participants in a grid on the right.
///   • Narrow (< [mobileBreakpoint]) → "column": speaker pinned to the top,
///     full-bleed (no padding), participants on a strip below.
///   • Single breakpoint: orientation and padding flip together.
///   • [speaker] == null → no featured tile (e.g. the local user is the one
///     speaking and has no self-view); the participant grid fills the area.
///
/// You only supply the video widgets — drop any [Widget] into [speaker] and
/// [participants] (a texture, platform view, image, decorated box, etc.).
///
/// Layout is done by a single [CustomMultiChildLayout]: one render object holds
/// every tile and just re-positions them in [_CallLayoutDelegate.performLayout]
/// when the size changes. There is no `LayoutBuilder` rebuild on resize and no
/// orientation-dependent widget swap, so tile state (and bound video streams)
/// survives the breakpoint and the speaker toggle automatically — keys on the
/// [participants] are enough to keep state attached across reorders.
class AdaptiveCallLayout extends StatelessWidget {
  const AdaptiveCallLayout({
    required this.participants,
    super.key,
    this.speaker,
    this.spacing = 10,
    this.tileAspectRatio = 4 / 5, // width / height
    this.mobileBreakpoint = 540,
    this.desktopPadding = 16,
    this.mobilePadding = 0,
    this.speakerMaxWidthFraction = 0.62,
    this.portraitMinStripFraction = 0.20,
    this.portraitMinStrip = 70,
    this.portraitMaxStrip = 150,
  }) : assert(tileAspectRatio > 0, 'tileAspectRatio must be > 0');

  /// The active speaker, rendered large. Pass `null` for no featured tile.
  final Widget? speaker;

  /// Everyone else — laid out as equal, fixed-ratio tiles in an adaptive grid.
  final List<Widget> participants;

  /// Gap between tiles (and between speaker and grid), in logical pixels.
  final double spacing;

  /// Tile aspect ratio as width / height. 4:5 portrait => 0.8.
  final double tileAspectRatio;

  /// Below this width the layout switches to the stacked "mobile" form.
  final double mobileBreakpoint;

  /// Outer padding on desktop / mobile respectively (mobile is full-bleed).
  final double desktopPadding;
  final double mobilePadding;

  /// In the landscape "row" form, the speaker may grow up to this fraction of
  /// the width before listeners start claiming space.
  final double speakerMaxWidthFraction;

  /// In the stacked "column" form, how much height to reserve for the
  /// participant strip beneath the speaker.
  final double portraitMinStripFraction;
  final double portraitMinStrip;
  final double portraitMaxStrip;

  @override
  Widget build(BuildContext context) {
    return CustomMultiChildLayout(
      delegate: _CallLayoutDelegate(
        hasSpeaker: speaker != null,
        participantCount: participants.length,
        spacing: spacing,
        tileAspectRatio: tileAspectRatio,
        mobileBreakpoint: mobileBreakpoint,
        desktopPadding: desktopPadding,
        mobilePadding: mobilePadding,
        speakerMaxWidthFraction: speakerMaxWidthFraction,
        portraitMinStripFraction: portraitMinStripFraction,
        portraitMinStrip: portraitMinStrip,
        portraitMaxStrip: portraitMaxStrip,
      ),
      children: [
        if (speaker != null)
          LayoutId(
            // Carry the speaker's key so a participant promoted into (or
            // demoted out of) the featured slot reuses its element — state and
            // bound video stream ride along instead of being rebound.
            key: speaker!.key,
            id: _speakerSlot,
            child: RepaintBoundary(child: speaker),
          ),
        // The id is positional (= grid slot); the caller's key drives element
        // reuse, so a reordered participant moves to its new slot with state
        // intact. RepaintBoundary isolates each (continuously repainting) tile.
        for (var i = 0; i < participants.length; i++)
          LayoutId(
            key: participants[i].key,
            id: i,
            child: RepaintBoundary(child: participants[i]),
          ),
      ],
    );
  }
}

/// Layout id for the featured speaker slot. Participant slots use their integer
/// index, so this just needs to be a stable, distinct, equatable value.
const Object _speakerSlot = #speaker;

/// Positions the speaker + participant tiles. All geometry comes from [_solve];
/// this delegate only maps the resolved spec onto child offsets.
class _CallLayoutDelegate extends MultiChildLayoutDelegate {
  _CallLayoutDelegate({
    required this.hasSpeaker,
    required this.participantCount,
    required this.spacing,
    required this.tileAspectRatio,
    required this.mobileBreakpoint,
    required this.desktopPadding,
    required this.mobilePadding,
    required this.speakerMaxWidthFraction,
    required this.portraitMinStripFraction,
    required this.portraitMinStrip,
    required this.portraitMaxStrip,
  });

  final bool hasSpeaker;
  final int participantCount;
  final double spacing;
  final double tileAspectRatio;
  final double mobileBreakpoint;
  final double desktopPadding;
  final double mobilePadding;
  final double speakerMaxWidthFraction;
  final double portraitMinStripFraction;
  final double portraitMinStrip;
  final double portraitMaxStrip;

  @override
  void performLayout(Size size) {
    final spec = _solve(width: size.width, height: size.height);
    final pad = spec.padding;
    final contentW = math.max(0.0, size.width - 2 * pad);
    final contentH = math.max(0.0, size.height - 2 * pad);

    // A degenerate (zero-area) speaker or grid is hidden, mirroring the old
    // `> 0` guards: such children still must be laid out exactly once.
    final showSpeaker = hasSpeaker && spec.speakerW > 0 && spec.speakerH > 0;
    final showGrid = participantCount > 0 && spec.tileW > 0 && spec.tileH > 0;

    final gridW = spec.gridContentWidth;
    final gridH = spec.rows > 0
        ? spec.rows * spec.tileH + (spec.rows - 1) * spacing
        : 0.0;

    // Resolve the top-left of the speaker box and of the grid block, matching
    // the old Flex/Center behaviour exactly.
    var speakerPos = Offset(pad, pad);
    var gridPos = Offset(pad, pad);
    if (showSpeaker && showGrid) {
      if (spec.isRow) {
        // Landscape: [speaker | gap | grid] centred as a group, v-centred.
        final groupW = spec.speakerW + spacing + gridW;
        final startX = pad + math.max(0.0, (contentW - groupW) / 2);
        speakerPos = Offset(startX, pad + (contentH - spec.speakerH) / 2);
        gridPos = Offset(
          startX + spec.speakerW + spacing,
          pad + (contentH - gridH) / 2,
        );
      } else {
        // Portrait: speaker pinned to the top, grid below; both h-centred.
        speakerPos = Offset(pad + (contentW - spec.speakerW) / 2, pad);
        gridPos = Offset(
          pad + (contentW - gridW) / 2,
          pad + spec.speakerH + spacing,
        );
      }
    } else if (showSpeaker) {
      speakerPos = Offset(
        pad + (contentW - spec.speakerW) / 2,
        pad + (contentH - spec.speakerH) / 2,
      );
    } else if (showGrid) {
      gridPos = Offset(
        pad + (contentW - gridW) / 2,
        pad + (contentH - gridH) / 2,
      );
    }

    // Speaker — laid out exactly once (sized to zero when hidden).
    if (hasChild(_speakerSlot)) {
      if (showSpeaker) {
        layoutChild(
          _speakerSlot,
          BoxConstraints.tight(Size(spec.speakerW, spec.speakerH)),
        );
        positionChild(_speakerSlot, speakerPos);
      } else {
        layoutChild(_speakerSlot, BoxConstraints.tight(Size.zero));
      }
    }

    // Participant tiles — each laid out exactly once. Rows are centred and the
    // final partial row is centred within the grid width (matches Wrap).
    for (var i = 0; i < participantCount; i++) {
      if (!hasChild(i)) continue;
      if (!showGrid) {
        layoutChild(i, BoxConstraints.tight(Size.zero));
        continue;
      }
      final r = i ~/ spec.cols;
      final c = i % spec.cols;
      final inRow = (r < spec.rows - 1)
          ? spec.cols
          : participantCount - (spec.rows - 1) * spec.cols;
      final rowW = inRow * spec.tileW + (inRow - 1) * spacing;
      final rowStartX = gridPos.dx + (gridW - rowW) / 2;
      layoutChild(i, BoxConstraints.tight(Size(spec.tileW, spec.tileH)));
      positionChild(
        i,
        Offset(
          rowStartX + c * (spec.tileW + spacing),
          gridPos.dy + r * (spec.tileH + spacing),
        ),
      );
    }
  }

  /// Pure layout solver — no side effects, depends only on the incoming size.
  _LayoutSpec _solve({required double width, required double height}) {
    final w = math.max(60.0, width);
    final h = math.max(60.0, height);
    final aspect = tileAspectRatio; // width / height

    final mobile = w < mobileBreakpoint;
    final pad = mobile ? mobilePadding : desktopPadding;
    final iw = math.max(40.0, w - 2 * pad); // usable content width
    final ih = math.max(40.0, h - 2 * pad); // usable content height
    final isRow = !mobile;

    final hasFeatured = hasSpeaker;
    final m = participantCount;

    double fw = 0;
    double fh = 0;
    double gridW = iw;
    double gridH = ih;

    if (hasFeatured) {
      if (m == 0) {
        // Speaker fills the whole area.
        fh = math.min(ih, iw / aspect);
        fw = fh * aspect;
        if (fw > iw) {
          fw = iw;
          fh = math.min(ih, fw / aspect);
        }
        gridW = 0;
        gridH = 0;
      } else if (isRow) {
        // Landscape: speaker takes the lion's share of the width.
        fh = ih;
        fw = fh * aspect;
        final maxFw = iw * speakerMaxWidthFraction;
        if (fw > maxFw) {
          fw = maxFw;
          fh = math.min(ih, fw / aspect);
          fw = fh * aspect;
        }
        gridW = iw - fw - spacing;
        gridH = ih;
      } else {
        // Portrait: full-width speaker on top, listeners on a strip below.
        final minStrip = math.max(
          portraitMinStrip,
          math.min(ih * portraitMinStripFraction, portraitMaxStrip),
        );
        fw = iw;
        fh = fw / aspect;
        if (fh > ih - minStrip) {
          fh = ih - minStrip;
          fw = fh * aspect;
        }
        if (fw > iw) {
          fw = iw;
          fh = fw / aspect;
        }
        gridW = iw;
        gridH = math.max(0, ih - fh - spacing);
      }
    }

    final g = m > 0
        ? _bestGrid(m, gridW, gridH, spacing, aspect)
        : const _Grid(0, 0, 0, 0);

    final tileW = g.tileW.floorToDouble();
    final tileH = g.tileH.floorToDouble();
    final gridContentWidth = g.cols > 0
        ? g.cols * tileW + (g.cols - 1) * spacing
        : 0.0;

    return _LayoutSpec(
      isRow: isRow,
      padding: pad,
      speakerW: fw.floorToDouble(),
      speakerH: fh.floorToDouble(),
      tileW: tileW,
      tileH: tileH,
      gridContentWidth: gridContentWidth,
      cols: g.cols,
      rows: g.rows,
    );
  }

  /// Pick the column count that maximizes tile size while keeping the fixed
  /// aspect ratio and fitting `m` tiles within `W` x `H`.
  static _Grid _bestGrid(int m, double W, double H, double gap, double aspect) {
    final w = math.max(0, W);
    final h = math.max(0, H);
    var best = _Grid(1, m, 0, 0);
    for (var c = 1; c <= m; c++) {
      final r = (m / c).ceil();
      final twByWidth = (w - (c - 1) * gap) / c;
      final twByHeight = ((h - (r - 1) * gap) / r) * aspect;
      final tw = math.min(twByWidth, twByHeight);
      if (tw > best.tileW) {
        best = _Grid(c, r, math.max(0, tw), math.max(0, tw / aspect));
      }
    }
    return best;
  }

  @override
  bool shouldRelayout(_CallLayoutDelegate old) =>
      hasSpeaker != old.hasSpeaker ||
      participantCount != old.participantCount ||
      spacing != old.spacing ||
      tileAspectRatio != old.tileAspectRatio ||
      mobileBreakpoint != old.mobileBreakpoint ||
      desktopPadding != old.desktopPadding ||
      mobilePadding != old.mobilePadding ||
      speakerMaxWidthFraction != old.speakerMaxWidthFraction ||
      portraitMinStripFraction != old.portraitMinStripFraction ||
      portraitMinStrip != old.portraitMinStrip ||
      portraitMaxStrip != old.portraitMaxStrip;
}

/// Result of [_CallLayoutDelegate._bestGrid]: `cols` x `rows` tiles sized
/// `tileW`/`tileH`.
class _Grid {
  const _Grid(this.cols, this.rows, this.tileW, this.tileH);
  final int cols;
  final int rows;
  final double tileW;
  final double tileH;
}

/// Fully-resolved layout for one set of constraints.
class _LayoutSpec {
  const _LayoutSpec({
    required this.isRow,
    required this.padding,
    required this.speakerW,
    required this.speakerH,
    required this.tileW,
    required this.tileH,
    required this.gridContentWidth,
    required this.cols,
    required this.rows,
  });

  final bool isRow;
  final double padding;
  final double speakerW;
  final double speakerH;
  final double tileW;
  final double tileH;
  final double gridContentWidth;
  final int cols;
  final int rows;
}

// ───────────────────────────────────────────────────────────────────────────
// Example usage — delete or adapt. Shows how to slot in your own video widgets.
//
//   AdaptiveCallLayout(
//     speaker: VideoView(stream: activeSpeakerStream),   // null while you speak
//     participants: [
//       for (final p in otherParticipants)
//         VideoView(key: ValueKey(p.id), stream: p.stream),
//     ],
//   )
//
// `speaker` and each `participants[i]` are laid out into correctly-sized boxes;
// make your video widget fill its box (e.g. FittedBox(fit: BoxFit.cover, ...)).
// Give each participant a stable key so its tile state survives reorders.
// ───────────────────────────────────────────────────────────────────────────
