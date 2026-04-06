import 'dart:math' as math;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

typedef OnActionPerformed = Future<bool> Function();

enum TotemCardTransitionType { join, pass, receive, start, waitingReceive }

class TransitionCardContainer extends StatelessWidget {
  const TransitionCardContainer({
    required this.children,
    this.margin = const EdgeInsetsDirectional.symmetric(horizontal: 30),
    super.key,
  });

  final EdgeInsetsGeometry margin;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          top: 12,
          start: 16,
          end: 16,
          bottom: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 15,
          children: children,
        ),
      ),
    );
  }
}

class TransitionCard extends StatelessWidget {
  const TransitionCard({
    required this.type,
    required this.onActionPressed,
    this.actionText,
    this.keepActionLoadingOnSuccess = false,
    this.isSliderLoading,
    this.margin = const EdgeInsetsDirectional.symmetric(horizontal: 30),
    super.key,
  });

  final TotemCardTransitionType type;
  final OnActionPerformed onActionPressed;
  final bool keepActionLoadingOnSuccess;
  final bool? isSliderLoading;

  final EdgeInsetsGeometry margin;
  final String? actionText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TransitionCardContainer(
      margin: margin,
      children: [
        if (type == TotemCardTransitionType.join)
          Column(
            spacing: 10,
            children: [
              Text(
                'Welcome',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
                textAlign: TextAlign.center,
              ),
              const Text(
                'Your session will start soon. Please check your audio and video before joining.',
                textAlign: TextAlign.center,
              ),
            ],
          )
        else
          AutoSizeText(
            switch (type) {
              TotemCardTransitionType.join => 'Swipe to join the session.',
              TotemCardTransitionType.pass =>
                'When done, slide to pass the Totem to the next person.',
              TotemCardTransitionType.receive =>
                'The Totem is being passed to you.',
              TotemCardTransitionType.start =>
                'Bring participants out of the waiting room and begin '
                    'the conversation.',
              TotemCardTransitionType.waitingReceive =>
                'Waiting for the receiver to accept...\n'
                    'It is still your turn',
            },
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        if (type != TotemCardTransitionType.waitingReceive)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 160,
              ),
              child: ActionSlider(
                text:
                    actionText ??
                    switch (type) {
                      TotemCardTransitionType.join => 'Swipe to Join',
                      TotemCardTransitionType.pass => 'Pass',
                      TotemCardTransitionType.receive => 'Receive',
                      TotemCardTransitionType.start => 'Start Session',
                      TotemCardTransitionType.waitingReceive =>
                        throw UnsupportedError(
                          'This should never be reached',
                        ),
                    },
                onActionCompleted: onActionPressed,
                keepLoadingOnSuccess: keepActionLoadingOnSuccess,
                isLoading: isSliderLoading,
              ),
            ),
          ),
      ],
    );
  }
}

class ActionSlider extends StatefulWidget {
  const ActionSlider({
    required this.text,
    required this.onActionCompleted,
    this.keepLoadingOnSuccess = false,
    this.isLoading,
    this.backgroundColor,
    super.key,
  });

  final String text;
  final OnActionPerformed onActionCompleted;
  final bool keepLoadingOnSuccess;
  final bool? isLoading;
  final Color? backgroundColor;

  @override
  State<ActionSlider> createState() => _ActionSliderState();
}

class _ActionSliderState extends State<ActionSlider> {
  var _dragPosition = 0.0;
  var _isCompleted = false;
  var _isLoading = false;
  double maxSlideDistance = 0.0;

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
      _completeAction(maxSlideDistance);
    }
  }

  void _onPanEnd(
    DragEndDetails details,
    double maxSlideDistance,
  ) {
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
      _completeAction(maxSlideDistance);
    } else {
      if (mounted) {
        setState(() {
          _dragPosition = 0.0;
        });
      }
    }
  }

  void _completeAction(double maxSlideDistance) async {
    final success = await widget.onActionCompleted();
    _isCompleted = success;
    _dragPosition = success ? maxSlideDistance : 0.0;
    _isLoading = success && widget.keepLoadingOnSuccess;
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(ActionSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading) {
      _isLoading = widget.isLoading ?? false;
      if (_isLoading) {
        _dragPosition = maxSlideDistance;
        _isCompleted = false;
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
        maxSlideDistance = trackWidth - thumbSize - (padding * 2);
        final progress = widget.isLoading == true
            ? 1
            : clampDouble(
                math.min(_dragPosition / maxSlideDistance, 1),
                0,
                1,
              );

        final backgroundColor =
            widget.backgroundColor ?? theme.colorScheme.primary;
        final foregroundColor = theme.colorScheme.onPrimary;

        TextStyle? baseTextStyle;
        final buttonStyle = theme.elevatedButtonTheme.style;
        if (buttonStyle != null) {
          baseTextStyle = buttonStyle.textStyle?.resolve({});
        }
        final textStyle = (baseTextStyle ?? theme.textTheme.labelLarge)
            ?.copyWith(color: foregroundColor);

        return GestureDetector(
          onPanUpdate: (details) => _onPanUpdate(details, maxSlideDistance),
          onPanEnd: (details) => _onPanEnd(details, maxSlideDistance),
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: AlignmentDirectional.center,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: thumbSize * 1.25,
                    ),
                    child: AutoSizeText(
                      widget.text,
                      style: textStyle?.copyWith(
                        color: foregroundColor.withValues(
                          alpha: 1.0 - progress,
                        ),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ),
                ),
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
                    child: widget.isLoading == true || _isLoading
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
