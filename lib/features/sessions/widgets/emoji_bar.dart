import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:totem_app/core/errors/error_handler.dart';

/// Displays an emoji bar above the given button context and calls
/// [onEmojiSelected] with the selected emoji.
Future<void> showEmojiBar(
  BuildContext context, {
  required ValueChanged<String> onEmojiSelected,
}) async {
  final navigator = Navigator.of(context).context;
  final box = context.findRenderObject() as RenderBox?;
  if (box == null) return;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return;
  final overlayPositionX = overlay
      .localToGlobal(
        Offset.zero,
        ancestor: navigator.findRenderObject(),
      )
      .dx;
  final boxY = box
      .localToGlobal(
        Offset.zero,
        ancestor: navigator.findRenderObject(),
      )
      .dy;
  final position = Offset(overlayPositionX, boxY);

  final completer = Completer<void>();
  OverlayEntry? entry;
  entry = OverlayEntry(
    builder: (context) {
      return SafeArea(
        left: false,
        top: false,
        bottom: true,
        right: true,
        child: _EmojiBarOverlay(
          position: position,
          onEmojiSelected: onEmojiSelected,
          onDismissed: () {
            completer.complete();
            if (entry?.mounted ?? false) {
              entry?.remove();
            }
          },
        ),
      );
    },
  );
  Overlay.of(navigator).insert(entry);
  return completer.future;
}

class _EmojiBarOverlay extends StatefulWidget {
  const _EmojiBarOverlay({
    required this.position,
    required this.onEmojiSelected,
    required this.onDismissed,
    // ignore: unused_element_parameter
    this.displayDuration = const Duration(seconds: 4),
  });

  final Offset position;
  final ValueChanged<String> onEmojiSelected;
  final Duration displayDuration;
  final VoidCallback onDismissed;

  @override
  State<_EmojiBarOverlay> createState() => _EmojiBarOverlayState();
}

class _EmojiBarOverlayState extends State<_EmojiBarOverlay>
    with SingleTickerProviderStateMixin {
  Timer? _timer;

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..forward();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.displayDuration, _dismiss);
  }

  void _dismiss() async {
    await _animationController.reverse();
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPosition = widget.position.dy - 70;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _dismiss,
            behavior: HitTestBehavior.translucent,
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
        Positioned(
          top: topPosition,
          left: widget.position.dx,
          right: 0,
          child: FadeTransition(
            opacity: _animationController,
            child: EmojiBar(
              onEmojiSelected: (emoji) {
                widget.onEmojiSelected(emoji);
                _startTimer();
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
  }
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
              children: [
                for (final emoji in emojis)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onEmojiSelected(emoji),
                    child: Text(
                      emoji,
                      style: const TextStyle(
                        fontSize: 24,
                        textBaseline: TextBaseline.ideographic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> displayReaction(
  BuildContext context,
  String emoji, {
  GlobalKey<OverlayState>? overlayKey,
}) async {
  final overlayBox =
      (overlayKey?.currentContext ?? Overlay.of(context).context)
              .findRenderObject()
          as RenderBox?;
  if (overlayBox == null) return;

  final box = context.findRenderObject() as RenderBox?;
  if (box == null) return;

  final position = box.localToGlobal(Offset.zero, ancestor: overlayBox);

  final overlay = overlayKey?.currentState ?? Overlay.of(context);

  final completer = Completer<void>();
  OverlayEntry? entry;

  try {
    entry = OverlayEntry(
      builder: (context) {
        return OrientationBuilder(
          builder: (context, orientation) {
            final double startX = switch (orientation) {
              Orientation.portrait => position.dx + box.size.width * 0.15,
              Orientation.landscape => position.dx + box.size.width * 0.4,
            };
            final double startY = switch (orientation) {
              Orientation.portrait => position.dy + box.size.height / 2,
              Orientation.landscape => position.dy + box.size.height / 4,
            };
            return Stack(
              children: [
                RisingEmoji(
                  emoji: emoji,
                  startX: startX,
                  startY: startY,
                  onCompleted: () {
                    completer.complete();
                    if (entry?.mounted ?? false) {
                      entry?.remove();
                      entry = null;
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    overlay.insert(entry!);
    await completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () => {},
    );
  } catch (error, stackTrace) {
    ErrorHandler.logError(
      error,
      stackTrace: stackTrace,
      message: 'Failed to show emoji reaction: $emoji',
    );
  } finally {
    if (entry?.mounted ?? false) {
      entry?.remove();
    }
  }
}

@visibleForTesting
class RisingEmoji extends StatefulWidget {
  const RisingEmoji({
    required this.emoji,
    required this.startX,
    required this.startY,
    required this.onCompleted,
    this.duration = const Duration(seconds: 2),
    this.sizeFactor = 1.0,
    super.key,
  });

  final String emoji;
  final double startX;
  final double startY;
  final VoidCallback onCompleted;
  final Duration duration;
  final double sizeFactor;

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

    _controller
      ..forward()
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onCompleted();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_animation, _opacityAnimation]),
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
                child: child,
              ),
            ),
          ),
        );
      },
      child: Text(
        widget.emoji,
        style: TextStyle(
          fontSize: 44 * widget.sizeFactor,
          textBaseline: TextBaseline.ideographic,
        ),
      ),
    );
  }
}
