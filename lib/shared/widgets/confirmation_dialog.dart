import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';

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
    this.iconSize = 90,
    this.type = ConfirmationDialogType.destructive,
    super.key,
  });

  final TotemIconData? icon;
  final Widget? iconWidget;
  final double iconSize;
  final String? title;
  final String content;
  final TextStyle? contentStyle;
  final String confirmButtonText;
  final Future<void> Function() onConfirm;
  final ConfirmationDialogType type;

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
      child: AlertDialog(
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
                if (widget.title != null)
                  Semantics(
                    header: true,
                    namesRoute: true,
                    child: Text(
                      widget.title!,
                      textAlign: TextAlign.center,
                      style:
                          (theme.dialogTheme.titleTextStyle ??
                                  theme.textTheme.titleLarge)
                              ?.copyWith(color: theme.colorScheme.onSurface),
                    ),
                  ),
              ],
            ),
            Text(
              widget.content,
              textAlign: TextAlign.center,
              style: widget.contentStyle,
            ),
            ElevatedButton(
              onPressed: () async {
                if (_loading) return;
                setState(() => _loading = true);
                await widget.onConfirm().timeout(
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
                if (mounted) {
                  setState(() {
                    _loading = false;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: switch (widget.type) {
                  ConfirmationDialogType.destructive => const Color(0xFFFF3B30),
                  ConfirmationDialogType.standard => theme.colorScheme.primary,
                },
                foregroundColor: switch (widget.type) {
                  ConfirmationDialogType.destructive => Colors.white,
                  ConfirmationDialogType.standard =>
                    theme.colorScheme.onPrimary,
                },
              ),
              child: _loading
                  ? const LoadingIndicator(
                      color: Colors.white,
                      size: 24,
                      semanticsLabel: 'Processing',
                    )
                  : Text(
                      widget.confirmButtonText,
                      textAlign: TextAlign.center,
                    ),
            ),
            OutlinedButton(
              onPressed: _loading ? null : () => context.pop(),
              child: const Text('Cancel', textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}
