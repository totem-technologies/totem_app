import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Displays an emoji bar above the given button context and returns the
/// selected emoji.
Future<String?> showEmojiBar(BuildContext button, BuildContext context) async {
  final box = button.findRenderObject() as RenderBox?;
  if (box == null) return null;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return null;
  final position = box.localToGlobal(Offset.zero, ancestor: overlay);

  final response = await Navigator.of(context).push<String>(
    PageRouteBuilder<String>(
      opaque: false,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
            PositionedDirectional(
              start: 20,
              end: 20,
              top: position.dy - 60,
              child: FadeTransition(
                opacity: animation,
                child: EmojiBar(
                  onEmojiSelected: (emoji) {
                    Navigator.of(context).pop(emoji);
                  },
                  emojis: const [
                    '👍',
                    '👏',
                    '😂',
                    '😍',
                    '😮',
                    '😢',
                    '🔥',
                    '💯',
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  return response;
}

class EmojiBar extends StatelessWidget {
  const EmojiBar({
    required this.emojis,
    required this.onEmojiSelected,
    super.key,
  });

  final List<String> emojis;
  final ValueChanged<String> onEmojiSelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        elevation: 6,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 15,
              vertical: 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: emojis.map((emoji) {
                return GestureDetector(
                  onTap: () => onEmojiSelected(emoji),
                  child: Text(
                    emoji,
                    style: const TextStyle(
                      fontSize: 24,
                      textBaseline: TextBaseline.ideographic,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> displayReaction(
  BuildContext context,
  String emoji,
) async {
  final overlayBox =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlayBox == null) return;

  final box = context.findRenderObject() as RenderBox?;
  if (box == null) return;

  final position = box.localToGlobal(Offset.zero, ancestor: overlayBox);

  final overlay = Overlay.of(context);

  final completer = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) {
      return RisingEmoji(
        emoji: emoji,
        startX: position.dx + box.size.width * 0.15,
        startY: box.size.height / 2,
        onCompleted: () {
          if (entry.mounted) {
            entry.remove();
          }
          completer.complete();
        },
      );
    },
  );

  overlay.insert(entry);
  return completer.future;
}

class RisingEmoji extends StatefulWidget {
  const RisingEmoji({
    required this.emoji,
    required this.startX,
    required this.startY,
    required this.onCompleted,
    this.duration = const Duration(milliseconds: 2000),
    super.key,
  });

  final String emoji;
  final double startX;
  final double startY;
  final VoidCallback onCompleted;
  final Duration duration;

  @override
  State<RisingEmoji> createState() => _RisingEmojiState();
}

class _RisingEmojiState extends State<RisingEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _opacityAnimation;

  final _random = math.Random();

  /// How wide the curve is
  late double _amplitude;

  /// How many curves it makes while rising
  late double _frequency;

  /// Whether it moves right first or left first
  late bool _movesRight;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _amplitude = _random.nextDouble() * 30 + 20;
    _frequency = _random.nextDouble() * 2 + 2;
    _movesRight = _random.nextBool();

    unawaited(_controller.forward().whenComplete(widget.onCompleted));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final screenHeight = MediaQuery.heightOf(context);

        // Vertical position (bottom to top)
        final bottom = (screenHeight / 2) * _animation.value;

        // Horizontal position (sine wave for curvy effect)
        final initialLeft = widget.startX;
        final angle = _controller.value * _frequency * math.pi;
        var horizontalOffset = math.sin(angle) * _amplitude;
        if (!_movesRight) horizontalOffset *= -1;

        return Positioned(
          bottom: widget.startY + bottom,
          left: initialLeft + horizontalOffset,
          child: Material(
            type: MaterialType.transparency,
            child: IgnorePointer(
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: Text(
                  widget.emoji,
                  style: const TextStyle(
                    fontSize: 22,
                    textBaseline: TextBaseline.ideographic,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
