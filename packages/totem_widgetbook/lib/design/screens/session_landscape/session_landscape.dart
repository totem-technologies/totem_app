import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../components/button/button.dart';
import '../../components/participant_card/participant_card.dart';
import '../../components/session_controls/session_controls.dart';
import '../../paint.dart';
import '../../tokens/tokens.dart';
import '../session_entry/entry_layer.dart';
import 'session_chat.dart';

/// Who holds the talking piece. Listening shows a featured speaker;
/// speaking shows an equal grid of everyone else plus a self-view.
enum LandscapeTurn { listening, speaking }

/// One person on camera. [photo] is a still standing in for video.
@immutable
class LandscapePerson {
  const LandscapePerson({required this.name, this.photo, this.isYou = false});

  final String name;
  final ImageProvider? photo;
  final bool isYou;
}

/// In-session circle, laid out for a phone (or tablet) on its side.
///
/// Portrait session layout does not rotate. A 4:5 tile that filled a
/// standing phone becomes a tall slab in landscape; `BoxFit.cover` then
/// chops the sides of a typical 16:9 / 4:3 camera and the face reads as
/// zoomed. The featured speaker also used to take a full-height column
/// (~40% of the short landscape width) and felt like it owned the room.
///
/// Landscape gets its own rules, not a scaled copy of portrait:
///
///   • Tiles are **4:3** — closer to a front camera than 4:5, so cover
///     keeps shoulders and room around the head.
///   • Tiles **do not stretch** to fill leftover space. Extra slate is
///     breathing room, not a bigger crop.
///   • Featured speaker is **capped** so one person cannot take over.
///   • Gallery / speaking grids pick a column count from how many
///     people are on camera, then size every tile the same.
///
/// Chrome (prompt, pass, controls) sits in a right-hand column so the
/// video cluster can stay compact. This is catalog-only — wire it into
/// the live session screens after review.
class SessionLandscape extends StatefulWidget {
  const SessionLandscape({
    super.key,
    required this.people,
    this.turn = LandscapeTurn.listening,
    this.prompt,
    this.nextName,
    this.micOn = true,
    this.cameraOn = true,
    this.reactionsOpen = false,
    this.onMic,
    this.onCamera,
    this.onPass,
    this.onChat,
    this.onReactions,
    this.onMore,
  });

  /// Everyone in the circle, including you. Order is talking order.
  final List<LandscapePerson> people;

  final LandscapeTurn turn;

  /// Round prompt. Speaking only — listening has no quote column.
  final String? prompt;

  /// Who receives the talking piece next. Drives "Next up" / "Pass to".
  final String? nextName;

  final bool micOn;
  final bool cameraOn;
  final bool reactionsOpen;
  final VoidCallback? onMic;
  final VoidCallback? onCamera;
  final VoidCallback? onPass;
  final VoidCallback? onChat;
  final VoidCallback? onReactions;
  final VoidCallback? onMore;

  @override
  State<SessionLandscape> createState() => _SessionLandscapeState();
}

class _SessionLandscapeState extends State<SessionLandscape> {
  /// Compact (phone, including landscape) uses a sheet. Regular
  /// (tablet / desktop) uses the 412 drawer. Same cut as the live
  /// session: shortest side under 600 is a phone.
  static const _phoneShortestSide = 600.0;

  /// Figma session chat rail (3518:9823).
  static const _chatDrawerWidth = 412.0;

  var _chatOpen = false;

  void _toggleChat() {
    setState(() => _chatOpen = !_chatOpen);
    widget.onChat?.call();
  }

  void _closeChat() {
    if (!_chatOpen) return;
    setState(() => _chatOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).shortestSide < _phoneShortestSide;

    return Semantics(
      container: true,
      label: 'session',
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _closeChat,
        },
        child: Focus(
          autofocus: true,
          child: ColoredBox(
            color: TotemColors.coreSlate,
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: TotemColors.coreCream),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 900;
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          wide ? Spacing.s24 : Spacing.s12,
                          wide ? Spacing.s20 : Spacing.s12,
                          wide ? Spacing.s24 : Spacing.s12,
                          wide ? Spacing.s20 : Spacing.s12,
                        ),
                        child: widget.turn == LandscapeTurn.speaking
                            ? _SpeakingStage(
                                people: widget.people,
                                prompt: widget.prompt,
                                nextName: widget.nextName,
                                micOn: widget.micOn,
                                cameraOn: widget.cameraOn,
                                reactionsOpen: widget.reactionsOpen,
                                onMic: widget.onMic,
                                onCamera: widget.onCamera,
                                onPass: widget.onPass,
                                onChat: _toggleChat,
                                onReactions: widget.onReactions,
                                onMore: widget.onMore,
                              )
                            : _ListeningStage(
                                people: widget.people,
                                nextName: widget.nextName,
                                micOn: widget.micOn,
                                cameraOn: widget.cameraOn,
                                reactionsOpen: widget.reactionsOpen,
                                onMic: widget.onMic,
                                onCamera: widget.onCamera,
                                onChat: _toggleChat,
                                onReactions: widget.onReactions,
                                onMore: widget.onMore,
                              ),
                      );
                    },
                  ),
                  // Phone: sheet from the bottom. Tablet / desktop: drawer
                  // from the right. Same spring as Session Entry so a flick
                  // carries and a grab mid-flight restarts from the live value.
                  // Key the layer on the size class — sheet offsets on Y,
                  // drawer on X, and mixing them mid-flight jumps the panel.
                  EntryLayer(
                    key: ValueKey(phone),
                    open: _chatOpen,
                    kind: phone ? LayerKind.sheet : LayerKind.panel,
                    label: 'Chat',
                    scrim: LayerScrim.soft,
                    dismissOnScrim: true,
                    onDismiss: _closeChat,
                    expandChild: true,
                    panelMaxWidth: _chatDrawerWidth,
                    sheetHeightFactor: 0.92,
                    background: TotemColors.coreCream,
                    child: SessionChat(onClose: _closeChat),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Landscape geometry
//
// 4:3 (width / height) is the landscape tile. Portrait session tiles are
// 4:5. Cover-fitting a 16:9 camera into 4:5 on a short landscape phone
// crops left and right until the head fills the frame. 4:3 leaves the
// hair, shoulders, and a strip of room — the "comfortable crop".
//
// Caps stop a two-person call from inflating those 4:3 boxes until a
// face is again the size of the screen. Leftover space stays slate.
// ---------------------------------------------------------------------------

/// width / height. Wider than the portrait 4:5 gallery card.
const landscapeTileAspect = 4 / 3;

/// Featured speaker: large, not a full-height takeover.
const _featuredMaxWidth = 340.0;
const _featuredMaxHeightFraction = 0.88;
const _featuredMaxWidthFraction = 0.42;

/// Equal-grid tiles. Comfortable on a phone side; not a poster.
const _gridMaxTileWidth = 220.0;

const _tileGap = 8.0;

/// Right-hand chrome (prompt / pass / controls) on the speaking turn.
const _chromeMin = 196.0;
const _chromeMax = 300.0;
const _chromeWidthFraction = 0.34;

/// Gallery column must remain wide enough for at least one 4:3 tile.
const _galleryMin = 168.0;

@immutable
class _TileGridSpec {
  const _TileGridSpec({
    required this.cols,
    required this.rows,
    required this.tileW,
    required this.tileH,
  });

  final int cols;
  final int rows;
  final double tileW;
  final double tileH;
}

/// Pick the column count that maximises tile size at [landscapeTileAspect]
/// without stretching past [maxTileW] or the available box.
_TileGridSpec _fitTiles({
  required int count,
  required double maxW,
  required double maxH,
  double aspect = landscapeTileAspect,
  double gap = _tileGap,
  double maxTileW = _gridMaxTileWidth,
}) {
  if (count <= 0 || maxW <= 0 || maxH <= 0) {
    return const _TileGridSpec(cols: 1, rows: 0, tileW: 0, tileH: 0);
  }

  var best = const _TileGridSpec(cols: 1, rows: 1, tileW: 0, tileH: 0);
  for (var cols = 1; cols <= count; cols++) {
    final rows = (count / cols).ceil();
    final twByWidth = (maxW - (cols - 1) * gap) / cols;
    final thByHeight = (maxH - (rows - 1) * gap) / rows;
    final twByHeight = thByHeight * aspect;
    final tw = math.min(twByWidth, math.min(twByHeight, maxTileW));
    if (tw > best.tileW) {
      best = _TileGridSpec(
        cols: cols,
        rows: rows,
        tileW: tw,
        tileH: tw / aspect,
      );
    }
  }
  return best;
}

Size _fitFeatured(Size available) {
  // Height first: never fill the short landscape edge edge-to-edge.
  var height = math.min(
    available.height * _featuredMaxHeightFraction,
    _featuredMaxWidth / landscapeTileAspect,
  );
  var width = height * landscapeTileAspect;
  width = math.min(
    width,
    math.min(available.width * _featuredMaxWidthFraction, _featuredMaxWidth),
  );
  height = width / landscapeTileAspect;
  if (height > available.height) {
    height = available.height;
    width = height * landscapeTileAspect;
  }
  return Size(width, height);
}

// ---------------------------------------------------------------------------
// Listening — featured speaker + gallery
// ---------------------------------------------------------------------------

class _ListeningStage extends StatelessWidget {
  const _ListeningStage({
    required this.people,
    required this.micOn,
    required this.cameraOn,
    required this.reactionsOpen,
    this.nextName,
    this.onMic,
    this.onCamera,
    this.onChat,
    this.onReactions,
    this.onMore,
  });

  final List<LandscapePerson> people;
  final String? nextName;
  final bool micOn;
  final bool cameraOn;
  final bool reactionsOpen;
  final VoidCallback? onMic;
  final VoidCallback? onCamera;
  final VoidCallback? onChat;
  final VoidCallback? onReactions;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final speaker = people.isEmpty ? null : people.first;
    final rest = people.length <= 1
        ? const <LandscapePerson>[]
        : people.sublist(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Cap first, then shrink further if the gallery would collapse.
        // Portrait used to give the speaker the full short-edge height;
        // that is the takeover we are designing out.
        final featured = _fitFeatured(constraints.biggest);
        final speakerW = rest.isEmpty
            ? featured.width
            : math.min(
                featured.width,
                math.max(0.0, constraints.maxWidth - _galleryMin - Spacing.s12),
              );
        final speakerH = speakerW / landscapeTileAspect;

        final controls = Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _Controls(
              micOn: micOn,
              cameraOn: cameraOn,
              reactionsOpen: reactionsOpen,
              onMic: onMic,
              onCamera: onCamera,
              onChat: onChat,
              onReactions: onReactions,
              onMore: onMore,
            ),
          ),
        );

        // Solo speaker: centre the capped card on the slate. A full-height
        // column is what made one person feel like they owned the phone.
        if (rest.isEmpty && speaker != null) {
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: _FeaturedTile(
                    person: speaker,
                    width: speakerW,
                    height: speakerH,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.s8),
              controls,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (speaker != null)
              Center(
                child: _FeaturedTile(
                  person: speaker,
                  width: speakerW,
                  height: speakerH,
                ),
              ),
            if (speaker != null && rest.isNotEmpty)
              const SizedBox(width: Spacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (nextName != null && nextName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.s8),
                      child: Text(
                        'Next up $nextName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TotemText.caption.copyWith(
                          color: fade(TotemColors.coreCream, 0.78),
                        ),
                      ),
                    ),
                  Expanded(
                    child: rest.isEmpty
                        ? const SizedBox.shrink()
                        : _CenteredGrid(people: rest),
                  ),
                  const SizedBox(height: Spacing.s8),
                  controls,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Speaking — equal grid + prompt / pass / self-view
// ---------------------------------------------------------------------------

class _SpeakingStage extends StatelessWidget {
  const _SpeakingStage({
    required this.people,
    required this.micOn,
    required this.cameraOn,
    required this.reactionsOpen,
    this.prompt,
    this.nextName,
    this.onMic,
    this.onCamera,
    this.onPass,
    this.onChat,
    this.onReactions,
    this.onMore,
  });

  final List<LandscapePerson> people;
  final String? prompt;
  final String? nextName;
  final bool micOn;
  final bool cameraOn;
  final bool reactionsOpen;
  final VoidCallback? onMic;
  final VoidCallback? onCamera;
  final VoidCallback? onPass;
  final VoidCallback? onChat;
  final VoidCallback? onReactions;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final you = people.where((person) => person.isYou).firstOrNull;
    final others = people.where((person) => !person.isYou).toList();
    final passLabel = (nextName != null && nextName!.isNotEmpty)
        ? 'Pass to $nextName'
        : 'Pass the talking piece';

    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep the prompt column readable without stealing the grid.
        // 160 is the smallest grid we still consider a video stage.
        final chromeW =
            (constraints.maxWidth < _chromeMin + 160
                    ? math.min(_chromeMin, constraints.maxWidth * 0.4)
                    : (constraints.maxWidth * _chromeWidthFraction).clamp(
                        _chromeMin,
                        _chromeMax,
                      ))
                .toDouble();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: others.isEmpty
                  ? const SizedBox.shrink()
                  : _CenteredGrid(people: others),
            ),
            const SizedBox(width: Spacing.s12),
            SizedBox(
              width: chromeW,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (you != null)
                    Align(
                      alignment: Alignment.topRight,
                      child: _SelfView(person: you),
                    ),
                  const Spacer(),
                  if (prompt != null && prompt!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.s16),
                      child: Text(
                        prompt!,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TotemText.body.copyWith(
                          color: fade(TotemColors.coreCream, 0.92),
                          fontStyle: FontStyle.italic,
                          height: 1.35,
                        ),
                      ),
                    ),
                  Button(
                    onPressed: onPass ?? () {},
                    block: true,
                    semanticLabel: passLabel,
                    child: Text(passLabel),
                  ),
                  const Spacer(),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _Controls(
                        micOn: micOn,
                        cameraOn: cameraOn,
                        reactionsOpen: reactionsOpen,
                        onMic: onMic,
                        onCamera: onCamera,
                        onChat: onChat,
                        onReactions: onReactions,
                        onMore: onMore,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tiles
// ---------------------------------------------------------------------------

class _FeaturedTile extends StatelessWidget {
  const _FeaturedTile({
    required this.person,
    required this.width,
    required this.height,
  });

  final LandscapePerson person;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Elevation on the speaker only. Gallery tiles sit flat on slate so
    // the featured card reads as the thicker, closer surface.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: Shadows.elevation2,
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: ParticipantCard(
          name: person.isYou ? '${person.name} (you)' : person.name,
          photo: person.photo,
          feature: true,
          showTalkingPiece: true,
        ),
      ),
    );
  }
}

class _SelfView extends StatelessWidget {
  const _SelfView({required this.person});

  final LandscapePerson person;

  static const _width = 96.0;
  static const _height = _width / landscapeTileAspect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: _height,
      child: ParticipantCard(
        name: '${person.name} (you)',
        photo: person.photo,
        showMore: false,
        showTalkingPiece: true,
      ),
    );
  }
}

/// Equal 4:3 tiles, centred as a cluster. Partial last rows stay centred
/// too — they do not stretch to fill the row, which is what made a lone
/// leftover tile feel like a second speaker.
class _CenteredGrid extends StatelessWidget {
  const _CenteredGrid({required this.people});

  final List<LandscapePerson> people;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = _fitTiles(
          count: people.length,
          maxW: constraints.maxWidth,
          maxH: constraints.maxHeight,
        );
        if (spec.tileW <= 0 || spec.rows <= 0) {
          return const SizedBox.shrink();
        }

        final rows = <List<LandscapePerson>>[
          for (var i = 0; i < people.length; i += spec.cols)
            people.sublist(i, math.min(i + spec.cols, people.length)),
        ];

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: _tileGap,
            children: [
              for (final row in rows)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: _tileGap,
                  children: [
                    for (final person in row)
                      SizedBox(
                        width: spec.tileW,
                        height: spec.tileH,
                        child: ParticipantCard(
                          name: person.isYou
                              ? '${person.name} (you)'
                              : person.name,
                          photo: person.photo,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.micOn,
    required this.cameraOn,
    required this.reactionsOpen,
    this.onMic,
    this.onCamera,
    this.onChat,
    this.onReactions,
    this.onMore,
  });

  final bool micOn;
  final bool cameraOn;
  final bool reactionsOpen;
  final VoidCallback? onMic;
  final VoidCallback? onCamera;
  final VoidCallback? onChat;
  final VoidCallback? onReactions;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    // 40px buttons keep the glass pill under the short landscape edge
    // without crowding the tiles above it.
    return SessionControls(
      micOn: micOn,
      cameraOn: cameraOn,
      reactionsOpen: reactionsOpen,
      showSessionActions: true,
      tone: SessionControlsTone.glass,
      buttonSize: 40,
      onMic: onMic ?? () {},
      onCamera: onCamera ?? () {},
      onChat: onChat,
      onReactions: onReactions,
      onMore: onMore,
    );
  }
}
