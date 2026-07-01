import 'dart:math' as math;
import 'dart:ui';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

typedef OnActionPerformed = AsyncValueGetter<bool>;

class ActionSliderButton extends StatefulWidget {
  const ActionSliderButton({
    required this.text,
    required this.onActionCompleted,
    this.keepLoadingOnSuccess = false,
    this.isLoading,
    this.backgroundColor,
    this.focusNode,
    this.autofocus = true,
    super.key,
  });

  final String text;
  final OnActionPerformed onActionCompleted;
  final bool keepLoadingOnSuccess;
  final bool? isLoading;
  final Color? backgroundColor;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<ActionSliderButton> createState() => _ActionSliderButtonState();
}

class _ActionSliderButtonState extends State<ActionSliderButton> {
  late bool _hasMouseConnected;

  @override
  void initState() {
    super.initState();
    _hasMouseConnected = RendererBinding.instance.mouseTracker.mouseIsConnected;
    RendererBinding.instance.mouseTracker.addListener(
      _handleMouseConnectionChanged,
    );
  }

  @override
  void dispose() {
    RendererBinding.instance.mouseTracker.removeListener(
      _handleMouseConnectionChanged,
    );
    super.dispose();
  }

  void _handleMouseConnectionChanged() {
    final hasMouseConnected =
        RendererBinding.instance.mouseTracker.mouseIsConnected;
    if (_hasMouseConnected == hasMouseConnected || !mounted) {
      return;
    }

    setState(() {
      _hasMouseConnected = hasMouseConnected;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasMouseConnected) {
      return ActionSlider(
        text: widget.text,
        onActionCompleted: widget.onActionCompleted,
        keepLoadingOnSuccess: widget.keepLoadingOnSuccess,
        isLoading: widget.isLoading,
        backgroundColor: widget.backgroundColor,
        autofocus: widget.autofocus,
      );
    }

    return ActionButton(
      text: widget.text,
      onActionCompleted: widget.onActionCompleted,
      keepLoadingOnSuccess: widget.keepLoadingOnSuccess,
      isLoading: widget.isLoading,
      backgroundColor: widget.backgroundColor,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
    );
  }
}

@visibleForTesting
class ActionButton extends StatefulWidget {
  const ActionButton({
    required this.text,
    required this.onActionCompleted,
    this.keepLoadingOnSuccess = false,
    this.isLoading,
    this.backgroundColor,
    this.focusNode,
    this.autofocus = true,
    super.key,
  });

  final String text;
  final OnActionPerformed onActionCompleted;
  final bool keepLoadingOnSuccess;
  final bool? isLoading;
  final Color? backgroundColor;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  var _isLoading = false;

  Future<void> _onPressed() async {
    if (widget.isLoading == true || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final success = await widget.onActionCompleted();
    if (!mounted) return;

    setState(() {
      _isLoading = success && widget.keepLoadingOnSuccess;
    });
  }

  @override
  void didUpdateWidget(covariant ActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading && widget.isLoading != null) {
      _isLoading = widget.isLoading!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = widget.backgroundColor ?? theme.colorScheme.primary;
    final foregroundColor = theme.colorScheme.onPrimary;
    final effectiveLoading = widget.isLoading ?? _isLoading;

    return SizedBox(
      height: 50,
      child: ElevatedButton(
        autofocus: widget.autofocus,
        focusNode: widget.focusNode,
        onPressed: effectiveLoading ? null : _onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 40),
        ),
        child: effectiveLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator.adaptive(
                  strokeWidth: 2,
                  strokeCap: StrokeCap.round,
                ),
              )
            : AutoSizeText(widget.text, maxLines: 1),
      ),
    );
  }
}

@visibleForTesting
class ActionSlider extends StatefulWidget {
  const ActionSlider({
    required this.text,
    required this.onActionCompleted,
    this.keepLoadingOnSuccess = false,
    this.isLoading,
    this.backgroundColor,
    this.autofocus = true,
    super.key,
  });

  final String text;
  final OnActionPerformed onActionCompleted;
  final bool keepLoadingOnSuccess;
  final bool? isLoading;
  final Color? backgroundColor;
  final bool autofocus;

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
        assert(trackWidth > 0, 'ActionSlider must have a positive width');
        assert(trackWidth.isFinite, 'ActionSlider width must be finite');

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

        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.space): () {
              if (!_isCompleted && !_isLoading && widget.isLoading != true) {
                setState(() {
                  _dragPosition = maxSlideDistance;
                  _isCompleted = true;
                  _isLoading = true;
                });
                FocusManager.instance.primaryFocus?.unfocus();
                _completeAction(maxSlideDistance);
              }
            },
          },
          child: Focus(
            autofocus: widget.autofocus,
            child: GestureDetector(
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
                                  child:
                                      const CircularProgressIndicator.adaptive(
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
            ),
          ),
        );
      },
    );
  }
}
