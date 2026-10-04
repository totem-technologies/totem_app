import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Browser-style `:focus-visible`. Flutter on desktop and web always
/// highlights focus, so whatever holds focus on launch would get a ring.
/// Here rings appear once Tab moves focus and hide on the next pointer press.
class _FocusVisible extends ValueNotifier<bool> {
  _FocusVisible() : super(false) {
    HardwareKeyboard.instance.addHandler(_onKey);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab)
      value = true;
    return false;
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) value = false;
  }
}

final _focusVisible = _FocusVisible();

/// The one tap target every control is built on.
///
/// It gives controls the same feel everywhere:
/// - Press feedback on pointer-down, not on release.
/// - Hover only shows for real pointers (mouse), never on touch.
/// - The focus ring only shows after Tab, like `:focus-visible`.
/// - Reduced motion turns the press scale off.
///
/// A null [onTap] disables the control.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.builder,
    this.pressedScale = 1,
    this.focusColor,
    this.focusOffset = 2,
    this.focusRadius = BorderRadius.zero,
    this.semanticLabel,
    this.toggled,
    this.selected,
    this.expanded,
    this.excludeChildSemantics = false,
  });

  final VoidCallback? onTap;

  /// Paints the control for the current hover / press / focus / disabled state.
  final Widget Function(BuildContext context, Set<WidgetState> states) builder;

  /// Scale while the pointer is down. 1 means no press animation.
  final double pressedScale;

  /// Focus ring color. No ring when null.
  final Color? focusColor;

  /// Gap between the control and its 2px focus ring.
  final double focusOffset;

  /// The control's own corner radius. The ring grows it by the offset.
  final BorderRadius focusRadius;

  final String? semanticLabel;
  final bool? toggled;
  final bool? selected;
  final bool? expanded;

  /// Use [semanticLabel] instead of the text inside the control.
  final bool excludeChildSemantics;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null;

  @override
  void initState() {
    super.initState();
    _focusVisible.addListener(_onFocusVisibleChanged);
  }

  @override
  void dispose() {
    _focusVisible.removeListener(_onFocusVisibleChanged);
    super.dispose();
  }

  void _onFocusVisibleChanged() {
    if (_focused) setState(() {});
  }

  Set<WidgetState> get _states => {
    if (!_enabled) WidgetState.disabled,
    if (_enabled && _hovered) WidgetState.hovered,
    if (_enabled && _pressed) WidgetState.pressed,
    if (_enabled && _focused && _focusVisible.value) WidgetState.focused,
  };

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(Pressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) {
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final scale = _pressed && !reduceMotion ? widget.pressedScale : 1.0;

    Widget child = widget.builder(context, _states);

    if (widget.pressedScale != 1) {
      child = AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: child,
      );
    }

    final ringColor = widget.focusColor;
    if (ringColor != null) {
      final inset = -(widget.focusOffset + 2);
      child = Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (_states.contains(WidgetState.focused))
            Positioned(
              left: inset,
              top: inset,
              right: inset,
              bottom: inset,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: ringColor, width: 2),
                    borderRadius: widget.focusRadius.add(
                      BorderRadius.circular(widget.focusOffset + 2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      toggled: widget.toggled,
      selected: widget.selected,
      expanded: widget.expanded,
      excludeSemantics: widget.excludeChildSemantics,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onFocusChange: (value) => setState(() => _focused = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapUp: _enabled ? (_) => _setPressed(false) : null,
          onTapCancel: _enabled ? () => _setPressed(false) : null,
          onTap: widget.onTap,
          child: child,
        ),
      ),
    );
  }
}
