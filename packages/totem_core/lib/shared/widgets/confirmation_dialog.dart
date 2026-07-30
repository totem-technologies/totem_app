import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  final List<Widget> extraButtons;

  @override
  State<ConfirmationDialog> createState() => ConfirmationDialogState();
}

class ConfirmationDialogState extends State<ConfirmationDialog> {
  var _loading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconSize = MediaQuery.textScalerOf(context).scale(widget.iconSize);
    return PopScope(
      canPop: !_loading,
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
                                ?.copyWith(color: theme.colorScheme.onSurface),
                      ),
                    ),
                    Text(
                      widget.content,
                      textAlign: TextAlign.center,
                      style: widget.contentStyle,
                    ),
                  ],
                ),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    ConfirmationDialogButton.elevated(
                      isLoading: _loading,
                      onLoadingChanged: (loading) {
                        if (mounted) setState(() => _loading = loading);
                      },
                      onConfirm: widget.onConfirm,
                      type: widget.type,
                      child: Text(widget.confirmButtonText),
                    ),
                    ...widget.extraButtons.map((button) {
                      if (button is ConfirmationDialogButton) {
                        if (button._outlined) {
                          return ConfirmationDialogButton.outlined(
                            key: button.key,
                            isLoading: button.isLoading ?? _loading,
                            onLoadingChanged:
                                button.onLoadingChanged ??
                                (loading) {
                                  if (mounted) {
                                    setState(() => _loading = loading);
                                  }
                                },
                            onConfirm: button.onConfirm,
                            type: button.type,
                            child: button.child,
                          );
                        }
                        return ConfirmationDialogButton.elevated(
                          key: button.key,
                          isLoading: button.isLoading ?? _loading,
                          onLoadingChanged:
                              button.onLoadingChanged ??
                              (loading) {
                                if (mounted) setState(() => _loading = loading);
                              },
                          onConfirm: button.onConfirm,
                          type: button.type,
                          child: button.child,
                        );
                      }
                      return button;
                    }),
                    if (widget.showCancel)
                      OutlinedButton(
                        onPressed: _loading ? null : () => context.pop(),
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

class ConfirmationDialogButton extends StatelessWidget {
  const ConfirmationDialogButton.elevated({
    required this.onConfirm,
    required this.child,
    this.isLoading,
    this.onLoadingChanged,
    this.type = ConfirmationDialogType.standard,
    super.key,
  }) : _outlined = false;

  const ConfirmationDialogButton.outlined({
    required this.onConfirm,
    required this.child,
    this.isLoading,
    this.onLoadingChanged,
    this.type = ConfirmationDialogType.standard,
    super.key,
  }) : _outlined = true;

  final bool _outlined;

  final bool? isLoading;
  final ValueChanged<bool>? onLoadingChanged;
  final AsyncCallback onConfirm;

  final ConfirmationDialogType type;
  final Widget child;

  Future<void> _onPressed(BuildContext context) async {
    if (isLoading ?? false) return;
    onLoadingChanged?.call(true);
    await onConfirm().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        if (context.mounted) {
          ErrorHandler.showErrorDialog(
            context,
            message: 'Something went wrong. Please try again.',
          );
        }
      },
    );
    onLoadingChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = switch (type) {
      ConfirmationDialogType.destructive => const Color(
        0xFFFF3B30,
      ),
      ConfirmationDialogType.standard => theme.colorScheme.primary,
    };
    final foregroundColor = switch (type) {
      ConfirmationDialogType.destructive => Colors.white,
      ConfirmationDialogType.standard => theme.colorScheme.onPrimary,
    };
    final child = isLoading ?? false
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
            child: this.child,
          );

    if (_outlined) {
      return OutlinedButton(
        onPressed: () => _onPressed(context),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: backgroundColor),
          foregroundColor: backgroundColor,
        ),
        child: child,
      );
    } else {
      return ElevatedButton(
        onPressed: () => _onPressed(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
        ),
        child: child,
      );
    }
  }
}
