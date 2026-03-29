import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/controllers/features/permissions_controller.dart';
import 'package:totem_app/features/sessions/widgets/permission_item_tile.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/sheet_drag_handle.dart';

Future<bool> showPermissionsRequestSheet(BuildContext context) async {
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
    final permissionsState = ref.watch(permissionsControllerProvider);
    final controller = ref.read(permissionsControllerProvider.notifier);
    final isReady = permissionsState.requiredPermissionsGranted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetDragHandle(
            margin: EdgeInsetsDirectional.only(top: 12, bottom: 12),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Get Ready for your session',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please review your preferences below to ensure a smooth '
                  'live experience. You can manage these permissions at any '
                  'time in your device settings.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
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
                      'Allow Totem to send you notification about session, '
                      'new blog and more',
                  isGranted: permissionsState.isNotificationGranted,
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
                  isGranted: permissionsState.isMicrophoneGranted,
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
                  isGranted: permissionsState.isCameraGranted,
                  onTap: controller.requestCamera,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (isReady) {
                        Navigator.of(context).pop(true);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please grant camera and microphone permissions to continue.',
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isReady ? AppTheme.mauve : AppTheme.gray,
                    ),
                    child: const Text('Continue'),
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
