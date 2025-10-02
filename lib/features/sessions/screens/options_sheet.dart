import 'package:flutter/material.dart';
import 'package:totem_app/features/profile/screens/delete_account.dart';
import 'package:totem_app/shared/totem_icons.dart';

Future<bool?> showLeaveDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return ConfirmationDialog(
        content: 'Are you sure you want to leave the session?',
        confirmButtonText: 'Yes',
        onConfirm: () async {
          Navigator.of(context).pop(true);
        },
      );
    },
  );
}

Future<void> showOptionsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: const Color(0xFFF3F1E9),
    builder: (context) {
      return const OptionsSheet();
    },
  );
}

class OptionsSheet extends StatelessWidget {
  const OptionsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: 20,
        end: 20,
        top: 10,
        bottom: 36,
      ),
      child: Column(
        spacing: 10,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OptionsSheetTile(
            title: 'Camera',
            icon: TotemIcons.cameraOn,
            onTap: () async {
              Navigator.of(context).pop();
            },
          ),
          OptionsSheetTile(
            title: 'Microphone',
            icon: TotemIcons.microphoneOn,
            onTap: () async {
              Navigator.of(context).pop();
            },
          ),
          OptionsSheetTile(
            title: 'Leave Session',
            icon: TotemIcons.leaveCall,
            type: OptionsSheetTileType.destructive,
            onTap: () async {
              Navigator.of(context).pop();
              final shouldLeave = await showLeaveDialog(context) ?? false;
              if (shouldLeave && context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
          ),
        ],
      ),
    );
  }
}

enum OptionsSheetTileType {
  destructive,
  normal,
}

class OptionsSheetTile extends StatelessWidget {
  const OptionsSheetTile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.type = OptionsSheetTileType.normal,
    super.key,
  });

  final String title;
  final TotemIconData icon;
  final VoidCallback onTap;
  final OptionsSheetTileType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: SizedBox.square(dimension: 24, child: TotemIcon(icon, size: 24)),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      tileColor: type == OptionsSheetTileType.destructive
          ? theme.colorScheme.errorContainer
          : Colors.white,
      textColor: type == OptionsSheetTileType.destructive
          ? theme.colorScheme.onErrorContainer
          : null,
      iconColor: type == OptionsSheetTileType.destructive
          ? theme.colorScheme.onErrorContainer
          : null,
    );
  }
}
