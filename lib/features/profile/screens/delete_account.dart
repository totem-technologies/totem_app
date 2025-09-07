import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';

Future<void> showDeleteAccountDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const DeleteAccountDialog(),
  );
}

Future<void> showLogoutDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const LogoutDialog(),
  );
}

class DeleteAccountDialog extends ConsumerWidget {
  const DeleteAccountDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider.notifier);
    return _ConfirmationDialog(
      content:
          'This action will permanently delete your account. '
          'Are you sure you want to continue?',
      confirmButtonText: 'Delete account',
      onConfirm: auth.deleteAccount,
    );
  }
}

class LogoutDialog extends ConsumerWidget {
  const LogoutDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider.notifier);
    return _ConfirmationDialog(
      content: 'Are you sure you want to log out?',
      confirmButtonText: 'Log out',
      onConfirm: auth.logout,
    );
  }
}

class _ConfirmationDialog extends StatefulWidget {
  const _ConfirmationDialog({
    required this.content,
    required this.confirmButtonText,
    required this.onConfirm,
  });

  final String content;
  final String confirmButtonText;
  final Future<void> Function() onConfirm;

  @override
  State<_ConfirmationDialog> createState() => _ConfirmationDialogState();
}

class _ConfirmationDialogState extends State<_ConfirmationDialog> {
  var _loading = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_loading,
      child: AlertDialog(
        title: const Text('Are you sure?', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.content,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (_loading) return;
                setState(() => _loading = true);
                await widget.onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                foregroundColor: Colors.white,
              ),
              child: _loading
                  ? const LoadingIndicator(color: Colors.white, size: 24)
                  : Text(widget.confirmButtonText),
            ),
            const SizedBox(height: 16),
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
