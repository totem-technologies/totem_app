import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

class EmojiBarOverlay extends StatefulWidget {
  const EmojiBarOverlay({
    required this.buttonKey,
    required this.onEmojiSelected,
    required this.onDismissed,
    super.key,
  });

  final GlobalKey buttonKey;
  final ValueChanged<String> onEmojiSelected;
  final VoidCallback onDismissed;

  @override
  State<EmojiBarOverlay> createState() => EmojiBarOverlayState();
}

class EmojiBarOverlayState extends State<EmojiBarOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..forward();

  bool _isDismissing = false;

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;
    await _animationController.reverse();
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPosition = () {
      final buttonBox =
          widget.buttonKey.currentContext?.findRenderObject() as RenderBox?;
      if (buttonBox == null || !buttonBox.hasSize) return 0.0;
      final buttonOffset = buttonBox.localToGlobal(
        Offset.zero,
        ancestor: context.findRenderObject() as RenderBox?,
      );
      return buttonOffset.dy - 70;
    }();

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
        PositionedDirectional(
          top: topPosition,
          start: 0,
          end: 0,
          child: FadeTransition(
            opacity: _animationController,
            child: EmojiBar(
              onEmojiSelected: (emoji) {
                widget.onEmojiSelected(emoji);
              },
              emojis: EmojiBar.defaultEmojis,
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

  static const defaultEmojis = ['🫶', '💖', '😢', '🔥', '👏', '🎉'];

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

Future<void> presentEmojiReaction(
  BuildContext context,
  String emoji, {
  GlobalKey<OverlayState>? overlayKey,
  bool isInListeningTurnScreen = false,
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
  var inserted = false;

  try {
    entry = OverlayEntry(
      builder: (context) {
        return ViewportResolver(
          builder: (context, viewportKind) {
            final double startX = switch (viewportKind) {
              ViewportKind.smallPortrait => position.dx + box.size.width * 0.15,
              ViewportKind.smallLandscape => position.dx + box.size.width * 0.4,
              ViewportKind.mediumPlus => position.dx + box.size.width * 0.075,
            };
            final double startY = switch (viewportKind) {
              ViewportKind.smallPortrait =>
                isInListeningTurnScreen
                    ? position.dy + box.size.height / 2
                    : position.dy + box.size.height / 12,
              ViewportKind.smallLandscape => position.dy + box.size.height / 4,
              ViewportKind.mediumPlus => position.dy + box.size.height / 16,
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
    inserted = true;
    SemanticsService.sendAnnouncement(
      View.of(context),
      emoji,
      Directionality.of(context),
    );
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
    // An entry inserted while no frames are rendered (e.g. hidden browser
    // tab) never mounts, but still sits in the overlay — remove it whenever
    // it was inserted, not only when it is mounted.
    if (inserted && entry != null) {
      entry!.remove();
      entry = null;
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
    // Preserve the real duration when the OS "reduce motion" setting is on;
    // otherwise the controller runs at 5% of its duration, which also cuts
    // short the corner emoji on the participant card, whose visibility is
    // tied to this animation completing.
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      animationBehavior: AnimationBehavior.preserve,
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
        weight: 92,
      ),
    ]).animate(_controller);

    _amplitude = _random.nextDouble() * 30 + 20;
    _frequency = _random.nextDouble() * 2 + 2;
    _movesRight = _random.nextBool();

    _controller
      ..forward()
      ..addStatusListener((status) {
        if (mounted && status == AnimationStatus.completed) {
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
    // With "reduce motion" enabled, skip the float animation entirely. The
    // controller still runs so onCompleted fires after the normal duration,
    // keeping the corner emoji on the participant card visible as usual.
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: Listenable.merge([_animation, _opacityAnimation]),
      builder: (context, child) {
        final screenHeight = MediaQuery.heightOf(context);

        final maxTravelDistance = (screenHeight / 2).clamp(200.0, 400.0);
        final bottom = maxTravelDistance * _animation.value;

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
      child: MediaQuery.withNoTextScaling(
        child: Text(
          widget.emoji,
          style: TextStyle(
            fontSize: 44 * widget.sizeFactor,
            textBaseline: TextBaseline.ideographic,
          ),
        ),
      ),
    );
  }
}
