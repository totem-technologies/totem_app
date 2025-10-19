import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/shared/widgets/confirmation_dialog.dart';

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
    return ConfirmationDialog(
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
    return ConfirmationDialog(
      content: 'Are you sure you want to log out?',
      confirmButtonText: 'Log out',
      onConfirm: auth.logout,
    );
  }
}
