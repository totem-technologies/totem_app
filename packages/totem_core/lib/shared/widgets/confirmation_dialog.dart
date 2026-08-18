import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/loading_indicator.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

enum ConfirmationDialogType { destructive, standard }

class ConfirmationDialog extends StatefulWidget {
  const ConfirmationDialog({
    required this.content,
    required this.confirmButtonText,
    required this.onConfirm,
    this.contentStyle,
    this.title = 'Are you sure?',
    this.icon,
    this.iconWidget,
    this.iconSize = 60,
    this.type = ConfirmationDialogType.destructive,
    this.showCancel = true,
    this.extraButtons = const [],
    this.contentWidget,
    this.scrollable = false,
    super.key,
  });

  final TotemIconData? icon;
  final Widget? iconWidget;
  final double iconSize;
  final String title;
  final String content;
  final TextStyle? contentStyle;
  final String confirmButtonText;
  final AsyncCallback onConfirm;
  final ConfirmationDialogType type;
  final bool showCancel;

  /// The extra buttons.
  ///
  /// It is displayed below the confirm button and above the cancel button, if any.
  final List<ConfirmationDialogButton> extraButtons;

  /// An optional widget rendered between the content text and the action
  /// buttons. Use this for form fields or other custom content.
  final Widget? contentWidget;

  /// Whether the dialog content should scroll when the viewport is too short.
  final bool scrollable;

  @override
  State<ConfirmationDialog> createState() => ConfirmationDialogState();
}

class ConfirmationDialogState extends State<ConfirmationDialog> {
  var _anyButtonBusy = false;

  void _onBusyChanged(bool busy) {
    if (mounted) setState(() => _anyButtonBusy = busy);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconSize = MediaQuery.textScalerOf(context).scale(widget.iconSize);
    return PopScope(
      canPop: !_anyButtonBusy,
      child: ViewportResolver(
        builder: (context, viewportKind) {
          final contentPadding = switch (viewportKind) {
            ViewportKind.mediumPlus => const EdgeInsets.symmetric(
              horizontal: 40,
              vertical: 24,
            ),
            _ => const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          };
          return AlertDialog(
            scrollable: widget.scrollable,
            constraints: const BoxConstraints(maxWidth: 480),
            contentPadding: contentPadding,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 20,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    if (widget.icon != null)
                      TotemIcon(
                        widget.icon!,
                        size: iconSize,
                        color: switch (widget.type) {
                          ConfirmationDialogType.destructive => Colors.red,
                          ConfirmationDialogType.standard =>
                            theme.colorScheme.primary,
                        },
                      )
                    else if (widget.iconWidget != null)
                      SizedBox.square(
                        dimension: iconSize,
                        child: Center(child: widget.iconWidget),
                      ),
                    Semantics(
                      header: true,
                      namesRoute: true,
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style:
                            (theme.dialogTheme.titleTextStyle ??
                                    theme.textTheme.titleLarge)
                                ?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                ),
                      ),
                    ),
                    Text(
                      widget.content,
                      textAlign: TextAlign.center,
                      style: widget.contentStyle?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (widget.contentWidget != null) widget.contentWidget!,
                  ],
                ),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    ConfirmationDialogButton.elevated(
                      onBusyChanged: _onBusyChanged,
                      disabled: _anyButtonBusy,
                      onConfirm: widget.onConfirm,
                      type: widget.type,
                      autofocus: switch (widget.type) {
                        ConfirmationDialogType.standard => true,
                        _ => false,
                      },
                      child: Text(
                        widget.confirmButtonText,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                      ),
                    ),
                    ...widget.extraButtons.map(
                      (b) => b._withBusyChanged(
                        onBusyChanged: _onBusyChanged,
                        disabled: _anyButtonBusy,
                      ),
                    ),
                    if (widget.showCancel)
                      OutlinedButton(
                        autofocus: switch (widget.type) {
                          ConfirmationDialogType.destructive => true,
                          _ => false,
                        },
                        onPressed: _anyButtonBusy
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancel',
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ConfirmationDialogButton extends StatefulWidget {
  const ConfirmationDialogButton.elevated({
    required this.onConfirm,
    required this.child,
    this.onBusyChanged,
    this.disabled = false,
    this.type = ConfirmationDialogType.standard,
    this.autofocus = false,
    super.key,
  }) : _outlined = false;

  const ConfirmationDialogButton.outlined({
    required this.onConfirm,
    required this.child,
    this.onBusyChanged,
    this.disabled = false,
    this.type = ConfirmationDialogType.standard,
    this.autofocus = false,
    super.key,
  }) : _outlined = true;

  final bool _outlined;
  final bool autofocus;

  final ValueChanged<bool>? onBusyChanged;
  final bool disabled;
  final AsyncCallback onConfirm;

  final ConfirmationDialogType type;
  final Widget child;

  ConfirmationDialogButton _withBusyChanged({
    required ValueChanged<bool>? onBusyChanged,
    required bool disabled,
  }) {
    if (_outlined) {
      return ConfirmationDialogButton.outlined(
        key: key,
        onBusyChanged: onBusyChanged,
        disabled: disabled,
        onConfirm: onConfirm,
        autofocus: autofocus,
        type: type,
        child: child,
      );
    }
    return ConfirmationDialogButton.elevated(
      key: key,
      onBusyChanged: onBusyChanged,
      disabled: disabled,
      onConfirm: onConfirm,
      autofocus: autofocus,
      type: type,
      child: child,
    );
  }

  @override
  State<ConfirmationDialogButton> createState() =>
      _ConfirmationDialogButtonState();
}

class _ConfirmationDialogButtonState extends State<ConfirmationDialogButton> {
  var _isLoading = false;

  Future<void> _onPressed() async {
    if (widget.disabled || _isLoading) return;
    setState(() => _isLoading = true);
    widget.onBusyChanged?.call(true);
    try {
      await widget.onConfirm().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (mounted) {
            ErrorHandler.showErrorDialog(
              context,
              message: 'Something went wrong. Please try again.',
            );
          }
        },
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
      widget.onBusyChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = switch (widget.type) {
      ConfirmationDialogType.destructive => const Color(
        0xFFFF3B30,
      ),
      ConfirmationDialogType.standard => theme.colorScheme.primary,
    };
    final foregroundColor = switch (widget.type) {
      ConfirmationDialogType.destructive => Colors.white,
      ConfirmationDialogType.standard => theme.colorScheme.onPrimary,
    };
    final child = _isLoading
        ? Builder(
            builder: (context) {
              return LoadingIndicator(
                color:
                    DefaultTextStyle.of(context).style.color ?? foregroundColor,
                size: 24,
                semanticsLabel: 'Processing',
              );
            },
          )
        : DefaultTextStyle.merge(
            textAlign: TextAlign.center,
            child: widget.child,
          );

    if (widget._outlined) {
      return OutlinedButton(
        autofocus: widget.autofocus,
        onPressed: (widget.disabled || _isLoading) ? null : _onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: backgroundColor),
          foregroundColor: backgroundColor,
        ),
        child: child,
      );
    } else {
      return ElevatedButton(
        autofocus: widget.autofocus,
        onPressed: (widget.disabled || _isLoading) ? null : _onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
        ),
        child: child,
      );
    }
  }
}
