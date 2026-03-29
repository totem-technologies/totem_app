import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/shared/totem_icons.dart';

Future<void> showBackgroundActivityDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const BackgroundActivityDialog(),
  );
}

class BackgroundActivityDialog extends StatelessWidget {
  const BackgroundActivityDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TotemIcon(
            TotemIcons.backgroundMode,
            size: 45,
            color: AppTheme.mauve,
          ),
          const SizedBox(height: 24),
          Text(
            'Stay connected',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Text(
            'To prevent your session from dropping when you switch apps, '
            "Totem needs to stay active in the background. We'll only "
            'use the minimum power needed to keep you online.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await FlutterForegroundTask.requestIgnoreBatteryOptimization();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Enable Background Mode'),
            ),
          ),
        ],
      ),
    );
  }
}
