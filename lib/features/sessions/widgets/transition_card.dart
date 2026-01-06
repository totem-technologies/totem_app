import 'dart:math' as math;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

enum TotemCardTransitionType { pass, receive, start }

class TransitionCard extends StatelessWidget {
  const TransitionCard({
    required this.type,
    required this.onActionPressed,
    super.key,
  });

  final TotemCardTransitionType type;
  final Future<bool> Function() onActionPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsetsDirectional.symmetric(horizontal: 30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          top: 14,
          start: 30,
          end: 30,
          bottom: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 15,
          children: [
            AutoSizeText(
              switch (type) {
                TotemCardTransitionType.pass =>
                  'When done, press Pass to pass the Totem to the next person.',
                TotemCardTransitionType.receive =>
                  'The Totem is being passed to you.',
                TotemCardTransitionType.start =>
                  'Bring participants out of the waiting room and begin '
                      'the conversation.',
              },
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 160,
              ),
              child: _SlideToActionButton(
                text: switch (type) {
                  TotemCardTransitionType.pass => 'Pass',
                  TotemCardTransitionType.receive => 'Receive',
                  TotemCardTransitionType.start => 'Start Session',
                },
                onActionCompleted: onActionPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideToActionButton extends StatefulWidget {
  const _SlideToActionButton({
    required this.text,
    required this.onActionCompleted,
  });

  final String text;
  final Future<bool> Function() onActionCompleted;

  @override
  State<_SlideToActionButton> createState() => _SlideToActionButtonState();
}

class _SlideToActionButtonState extends State<_SlideToActionButton> {
  var _dragPosition = 0.0;
  var _isCompleted = false;
  var _isLoading = false;

  Future<void> _onPanUpdate(
    DragUpdateDetails details,
    double maxSlideDistance,
  ) async {
    if (_isCompleted || _isLoading) return;

    setState(() {
      _dragPosition += details.delta.dx;
      _dragPosition = math.max(0, math.min(_dragPosition, maxSlideDistance));

      final progress = _dragPosition / maxSlideDistance;
      if (progress >= 0.95) {
        _isCompleted = true;
        _isLoading = true;
        _dragPosition = maxSlideDistance;
      }
    });

    if (_isLoading) {
      final success = await widget.onActionCompleted();
      _isCompleted = success;
      _dragPosition = success ? maxSlideDistance : 0.0;
      _isLoading = false;

      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _onPanEnd(
    DragEndDetails details,
    double maxSlideDistance,
  ) async {
    if (_isCompleted || _isLoading) return;

    final progress = _dragPosition / maxSlideDistance;
    final velocity = details.velocity.pixelsPerSecond.dx;

    // If user slides fast enough to the right or is close to completion,
    // complete the action
    if (progress >= 0.85 || (progress > 0.5 && velocity > 500)) {
      setState(() {
        _dragPosition = maxSlideDistance;
        _isCompleted = true;
        _isLoading = true;
      });
      final success = await widget.onActionCompleted();
      if (mounted) {
        setState(() {
          _isCompleted = success;
          _dragPosition = success ? maxSlideDistance : 0.0;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _dragPosition = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        const thumbSize = 48.0;
        const padding = 6.0;
        final maxSlideDistance = trackWidth - thumbSize - (padding * 2);
        final progress = math
            .min(_dragPosition / maxSlideDistance, 1)
            .clamp(0, 1);

        final backgroundColor = theme.colorScheme.primary;
        final foregroundColor = theme.colorScheme.onPrimary;

        TextStyle? baseTextStyle;
        final buttonStyle = theme.elevatedButtonTheme.style;
        if (buttonStyle != null) {
          baseTextStyle = buttonStyle.textStyle?.resolve({});
        }
        final textStyle = (baseTextStyle ?? theme.textTheme.labelLarge)
            ?.copyWith(
              color: foregroundColor,
            );

        return GestureDetector(
          onPanUpdate: (details) => _onPanUpdate(details, maxSlideDistance),
          onPanEnd: (details) => _onPanEnd(details, maxSlideDistance),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Opacity(
                    opacity: 1.0 - progress,
                    child: Text(
                      widget.text,
                      style: textStyle?.copyWith(
                        color: foregroundColor,
                      ),
                    ),
                  ),
                ),
                // Sliding thumb
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  left: padding + _dragPosition,
                  top: padding,
                  bottom: padding,
                  child: Container(
                    width: thumbSize,
                    decoration: BoxDecoration(
                      color: foregroundColor,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isLoading
                        ? Center(
                            child: Container(
                              width: 24,
                              height: 24,
                              alignment: AlignmentDirectional.center,
                              child: const CircularProgressIndicator.adaptive(
                                strokeWidth: 1.5,
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.arrow_forward_ios,
                            size: 20,
                            color: backgroundColor,
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
