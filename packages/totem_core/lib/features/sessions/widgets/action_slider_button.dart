import 'dart:math' as math;
import 'dart:ui';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/shared/totem_icons.dart';

typedef OnActionPerformed = AsyncValueGetter<bool>;

/// Centered chevron for the ActionSlider thumb. Do not reuse
/// [TotemIcons.arrowForward] here — that glyph is right-heavy in its viewBox.
const _sliderChevron = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M9.5 6.5L15.5 12L9.5 17.5" stroke="#262F37" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

class ActionSliderButton extends StatefulWidget {
  const ActionSliderButton({
    required this.text,
    required this.onActionCompleted,
    this.keepLoadingOnSuccess = false,
    this.isLoading,
    this.backgroundColor,
    this.focusNode,
    this.autofocus = true,
    this.enabled = true,
    this.height = 50,
    super.key,
  });

  final String text;
  final OnActionPerformed onActionCompleted;
  final bool keepLoadingOnSuccess;
  final bool? isLoading;
  final Color? backgroundColor;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;

  /// Docked cards shrink this to match the action bar buttons.
  final double height;

  @override
  State<ActionSliderButton> createState() => _ActionSliderButtonState();
}

class _ActionSliderButtonState extends State<ActionSliderButton> {
  // Platform check is stable — unlike mouseIsConnected, it doesn't flicker
  // when the pointer leaves the browser window.
  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) {
      // Touch variant intentionally does not auto-focus on enable —
      // the slider uses CallbackShortcuts for Space which works
      // globally, and stealing focus would disrupt on-screen keyboards.
      return ActionSlider(
        text: widget.text,
        onActionCompleted: widget.onActionCompleted,
        keepLoadingOnSuccess: widget.keepLoadingOnSuccess,
        isLoading: widget.isLoading,
        backgroundColor: widget.backgroundColor,
        autofocus: widget.autofocus,
        enabled: widget.enabled,
        height: widget.height,
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
      enabled: widget.enabled,
      height: widget.height,
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
    this.enabled = true,
    this.height = 50,
    super.key,
  });

  final String text;
  final OnActionPerformed onActionCompleted;
  final bool keepLoadingOnSuccess;
  final bool? isLoading;
  final Color? backgroundColor;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;

  /// Docked cards shrink this to match the action bar buttons.
  final double height;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  var _isLoading = false;
  FocusNode? _internalNode;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _internalNode = FocusNode();
    }
  }

  @override
  void dispose() {
    _internalNode?.dispose();
    super.dispose();
  }

  Future<void> _onPressed() async {
    if (!widget.enabled || widget.isLoading == true || _isLoading) return;

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
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode == null && widget.focusNode != null) {
        // Caller started providing a node — drop ours.
        _internalNode?.dispose();
        _internalNode = null;
      } else if (oldWidget.focusNode != null && widget.focusNode == null) {
        // Caller stopped providing a node — create ours.
        _internalNode = FocusNode();
      }
    }
    if (!oldWidget.enabled && widget.enabled && widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _effectiveFocusNode.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = widget.backgroundColor ?? AppTheme.mauve;
    const foregroundColor = AppTheme.white;
    final effectiveLoading = widget.isLoading ?? _isLoading;

    final radius = BorderRadius.circular(widget.height / 2);
    final onPressed = (!widget.enabled || effectiveLoading) ? null : _onPressed;

    // Flat mauve fill (DecoratedBox) plus light overlays. Desktop/web focus
    // mode otherwise paints a dark traditional focus ring that reads as a
    // black border on the CTA.
    return SizedBox(
      height: widget.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: radius,
        ),
        child: Theme(
          data: theme.copyWith(
            focusColor: AppTheme.white.withValues(alpha: 0.28),
            hoverColor: AppTheme.white.withValues(alpha: 0.10),
            highlightColor: Colors.transparent,
            splashColor: AppTheme.white.withValues(alpha: 0.14),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              autofocus: widget.autofocus,
              focusNode: _effectiveFocusNode,
              onTap: onPressed,
              borderRadius: radius,
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return AppTheme.white.withValues(alpha: 0.14);
                }
                if (states.contains(WidgetState.hovered)) {
                  return AppTheme.white.withValues(alpha: 0.10);
                }
                if (states.contains(WidgetState.focused)) {
                  return AppTheme.white.withValues(alpha: 0.08);
                }
                return Colors.transparent;
              }),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 40),
                child: Center(
                  child: effectiveLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                            strokeCap: StrokeCap.round,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              foregroundColor,
                            ),
                          ),
                        )
                      : AutoSizeText(
                          widget.text,
                          maxLines: 1,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: foregroundColor,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
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
    this.enabled = true,
    this.height = 50,
    super.key,
  });

  final String text;
  final OnActionPerformed onActionCompleted;
  final bool keepLoadingOnSuccess;
  final bool? isLoading;
  final Color? backgroundColor;
  final bool autofocus;
  final bool enabled;

  /// Docked cards shrink this to match the action bar buttons.
  final double height;

  @visibleForTesting
  static const thumbKey = Key('action_slider_thumb');

  @override
  State<ActionSlider> createState() => ActionSliderState();
}

@visibleForTesting
class ActionSliderState extends State<ActionSlider> {
  var _dragPosition = 0.0;
  var _isCompleted = false;
  var _isLoading = false;
  double maxSlideDistance = 0.0;

  Future<void> _onPanUpdate(
    DragUpdateDetails details,
    double maxSlideDistance,
  ) async {
    if (_isCompleted || _isLoading || !widget.enabled) return;

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

  void _onPanEnd(DragEndDetails details, double maxSlideDistance) {
    if (_isCompleted || _isLoading || !widget.enabled) return;

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

        const padding = 4.0;
        final thumbSize = widget.height - (padding * 2);
        maxSlideDistance = trackWidth - thumbSize - (padding * 2);
        final progress = widget.isLoading == true
            ? 1
            : clampDouble(math.min(_dragPosition / maxSlideDistance, 1), 0, 1);

        final backgroundColor = widget.backgroundColor ?? AppTheme.mauve;
        const foregroundColor = AppTheme.white;

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
              if (widget.enabled &&
                  !_isCompleted &&
                  !_isLoading &&
                  widget.isLoading != true) {
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
              onPanUpdate: widget.enabled
                  ? (details) => _onPanUpdate(details, maxSlideDistance)
                  : null,
              onPanEnd: widget.enabled
                  ? (details) => _onPanEnd(details, maxSlideDistance)
                  : null,
              child: Opacity(
                opacity: widget.enabled ? 1.0 : 0.5,
                child: SizedBox(
                  height: widget.height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(widget.height / 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(widget.height / 2),
                      child: Stack(
                        alignment: AlignmentDirectional.center,
                        children: [
                          Padding(
                            padding: EdgeInsetsDirectional.only(
                              start: thumbSize + padding * 2,
                              end: padding * 2,
                            ),
                            child: Center(
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
                            width: thumbSize,
                            height: thumbSize,
                            child: DecoratedBox(
                              key: ActionSlider.thumbKey,
                              decoration: const BoxDecoration(
                                color: foregroundColor,
                                shape: BoxShape.circle,
                                // Soft white halo covers dark AA fringe on mauve.
                                boxShadow: [
                                  BoxShadow(
                                    color: foregroundColor,
                                    blurRadius: 0.6,
                                    spreadRadius: 0.15,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: widget.isLoading == true || _isLoading
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child:
                                            CircularProgressIndicator.adaptive(
                                              strokeWidth: 1.5,
                                              strokeCap: StrokeCap.round,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    backgroundColor,
                                                  ),
                                            ),
                                      )
                                    : TotemIcon(
                                        _sliderChevron,
                                        size: 18,
                                        color: backgroundColor,
                                        fillColor: true,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
