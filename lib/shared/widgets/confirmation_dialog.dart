import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';

enum ConfirmationDialogType { destructive, standard }

class ConfirmationDialog extends StatefulWidget {
  const ConfirmationDialog({
    required this.content,
    required this.confirmButtonText,
    required this.onConfirm,
    this.icon,
    this.type = ConfirmationDialogType.destructive,
    super.key,
  });

  final TotemIconData? icon;
  final String content;
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
    return PopScope(
      canPop: !_loading,
      child: AlertDialog(
        title: const Text('Are you sure?', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 20,
          children: [
            if (widget.icon != null)
              TotemIcon(widget.icon!, size: 90, color: Colors.red),
            Text(
              widget.content,
              textAlign: TextAlign.center,
            ),
            ElevatedButton(
              onPressed: () async {
                if (_loading) return;
                setState(() => _loading = true);
                await widget.onConfirm();
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
                  ? const LoadingIndicator(color: Colors.white, size: 24)
                  : Text(widget.confirmButtonText),
            ),
            OutlinedButton(
              onPressed: _loading ? null : () => context.pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
