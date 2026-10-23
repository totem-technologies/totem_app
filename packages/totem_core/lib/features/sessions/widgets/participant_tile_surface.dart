import 'package:flutter/widgets.dart';

/// Shared clipping and paint isolation for video and its Flutter overlays.
class ParticipantTileSurface extends StatelessWidget {
  const ParticipantTileSurface({
    required this.children,
    this.clipBehavior = Clip.antiAlias,
    super.key,
  });

  final List<Widget> children;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: clipBehavior,
      child: Stack(children: children),
    ),
  );
}
