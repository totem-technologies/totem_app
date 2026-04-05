import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/controllers/features/permissions_controller.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/sheet_drag_handle.dart';

Future<void> showBackgroundActivityDialog(BuildContext context) async {
  final isIgnored = await FlutterForegroundTask.isIgnoringBatteryOptimizations;

  if (isIgnored || !context.mounted) {
    return;
  }

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
    final theme = Theme.of(context);
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
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'To prevent your session from dropping when you switch apps, '
            "Totem needs to stay active in the background. We'll only "
            'use the minimum power needed to keep you online.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
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
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text(
                'Enable Background Mode',
                softWrap: false,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> showPermissionsRequestSheet(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);

  try {
    final currentPermissions = await container.read(
      permissionsControllerProvider.future,
    );

    if (currentPermissions.requiredPermissionsGranted) {
      return true;
    }
  } catch (_) {
    // Fall back to showing the sheet if the initial permission read fails.
  }

  if (!context.mounted) return false;

  return await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: false,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        builder: (context) {
          return const SafeArea(
            child: PermissionsRequestSheet(),
          );
        },
      ) ??
      false;
}

class PermissionsRequestSheet extends ConsumerStatefulWidget {
  const PermissionsRequestSheet({super.key});

  @override
  ConsumerState<PermissionsRequestSheet> createState() =>
      _PermissionsRequestSheetState();
}

class _PermissionsRequestSheetState
    extends ConsumerState<PermissionsRequestSheet>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(permissionsControllerProvider.notifier).refreshStatuses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final permissionsState = ref
        .watch(permissionsControllerProvider)
        .asData
        ?.value;
    final controller = ref.read(permissionsControllerProvider.notifier);
    final isReady = permissionsState?.requiredPermissionsGranted ?? false;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetDragHandle(
            margin: EdgeInsetsDirectional.only(top: 12, bottom: 12),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Get ready for your session',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Review your preferences below for a smooth live '
                  'experience. You can manage these permissions anytime in '
                  'your device settings.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 32),
                PermissionItemTile(
                  icon: const TotemIcon(
                    TotemIcons.notification,
                    size: 25,
                  ),
                  title: 'Notification',
                  description:
                      'Allow Totem to send you notifications about sessions, '
                      'new blogs, and more',
                  isGranted: permissionsState?.isNotificationGranted ?? false,
                  onTap: controller.requestNotification,
                ),
                const SizedBox(height: 10),
                PermissionItemTile(
                  icon: const TotemIcon(
                    TotemIcons.microphoneOn,
                    size: 25,
                  ),
                  title: 'Mic',
                  description:
                      'To speak during sessions, Totem needs access to your '
                      'microphone.',
                  isGranted: permissionsState?.isMicrophoneGranted ?? false,
                  onTap: controller.requestMicrophone,
                ),
                const SizedBox(height: 10),
                PermissionItemTile(
                  icon: const TotemIcon(
                    TotemIcons.cameraOn,
                    size: 25,
                  ),
                  title: 'Camera',
                  description:
                      'Allow camera access so others can see you during '
                      'the live session. You can turn it off at any time.',
                  isGranted: permissionsState?.isCameraGranted ?? false,
                  onTap: controller.requestCamera,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isReady
                        ? () {
                            Navigator.of(context).pop(true);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isReady ? AppTheme.mauve : AppTheme.gray,
                    ),
                    child: Text(isReady ? 'Continue' : 'Grant Permissions'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PermissionItemTile extends StatelessWidget {
  const PermissionItemTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onTap,
    super.key,
  });

  final Widget icon;
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label:
          '$title permission, ${isGranted ? "granted" : "not granted"}. $description. Tap to grant permission.',
      child: Material(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: isGranted ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 24, height: 24, child: Center(child: icon)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamilySans,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamilySans,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: theme.colorScheme.onSurface,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _CircleCheckbox(isChecked: isGranted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleCheckbox extends StatelessWidget {
  const _CircleCheckbox({required this.isChecked});

  final bool isChecked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isChecked ? AppTheme.mauve : Colors.transparent,
        border: isChecked ? null : Border.all(color: AppTheme.gray, width: 1.5),
      ),
      child: isChecked
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}
