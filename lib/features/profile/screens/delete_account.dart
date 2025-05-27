import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';

Future<void> showDeleteAccountDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const DeleteAccountDialog(),
  );
}

class DeleteAccountDialog extends ConsumerWidget {
  const DeleteAccountDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider.notifier);
    return AlertDialog(
      title: const Text('Are you sure?', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          const Text(
            'This action will permanently delete your account. '
            'Are you sure you want to continue?',
            textAlign: TextAlign.center,
          ),
          ElevatedButton(
            onPressed: auth.deleteAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete account'),
          ),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
