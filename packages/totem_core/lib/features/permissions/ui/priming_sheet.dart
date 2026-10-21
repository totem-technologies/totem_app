import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/permissions/media_permission_controller.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/platform_info.dart';
import 'package:totem_core/features/permissions/policy.dart';
import 'package:totem_core/features/permissions/ui/recovery_content.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/sheet_drag_handle.dart';

/// Whether the priming sheet has anything to ask: the microphone, which
/// joining needs, can still be prompted for (X2). The optional camera alone
/// doesn't bring it back on every visit; turning the camera on asks for it
/// (X6).
bool shouldShowPrimingSheet(
  MediaPermissions permissions,
  PlatformInfo platform,
) =>
    userCaptureStep(permissions.microphone, platform) ==
    UserCaptureStep.requestFirst;

/// Explains the camera and microphone before the OS prompts for them.
///
/// Native only: on web, capture is the prompt. Dismissing it is fine; the
/// pre-join screen shows what's still needed.
Future<void> showMediaPrimingSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      // Scrolls when it doesn't fit, such as on a phone held sideways.
      builder: (_) => const SafeArea(
        child: SingleChildScrollView(child: MediaPrimingSheet()),
      ),
    );

class MediaPrimingSheet extends ConsumerWidget {
  const MediaPrimingSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final permissions =
        ref.watch(mediaPermissionControllerProvider) ??
        const MediaPermissions();
    final platform = ref.watch(platformInfoProvider);
    final controller = ref.read(mediaPermissionControllerProvider.notifier);
    final microphoneGranted = permissions.microphone == MediaPermission.granted;
    final microphoneAction = recoveryFor(
      permissions.microphone,
      null,
      platform,
    );

    Widget tile(MediaKind kind, TotemIconData icon, String title) {
      final granted = permissions[kind] == MediaPermission.granted;
      final action = recoveryFor(permissions[kind], null, platform);
      return _MediaPermissionTile(
        icon: TotemIcon(icon, size: 25),
        title: title,
        // The OS won't ask again, such as after a second refusal on
        // Android (A2), so the tile says where the fix is.
        description: action == RecoveryAction.openAppSettings
            ? "It's off in Settings. Tap to change it."
            : mediaPurpose(kind),
        isGranted: granted,
        tapHint: action == RecoveryAction.openAppSettings
            ? 'Tap to open Settings.'
            : 'Tap to allow.',
        // Only what a tap here can fix. Anything else, such as a busy or
        // restricted device, is explained on the pre-join screen.
        onTap: switch (action) {
          RecoveryAction.request => () => unawaited(controller.request(kind)),
          RecoveryAction.openAppSettings => () => unawaited(
            controller.openSettings(),
          ),
          _ => null,
        },
      );
    }

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
              spacing: 10,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Get ready for your session',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Totem needs your microphone. Your camera is up to you. You '
                  'can change these any time in Settings.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 22),
                tile(
                  MediaKind.microphone,
                  TotemIcons.microphoneOn,
                  'Microphone',
                ),
                tile(MediaKind.camera, TotemIcons.cameraOn, 'Camera'),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: switch (microphoneAction) {
                      // The microphone is the one device joining needs, so
                      // asking for it is the sheet's main action.
                      RecoveryAction.request => () => unawaited(
                        controller.request(MediaKind.microphone),
                      ),
                      RecoveryAction.openAppSettings => () => unawaited(
                        controller.openSettings(),
                      ),
                      _ => () => Navigator.of(context).pop(),
                    },
                    child: Text(switch (microphoneAction) {
                      RecoveryAction.request => 'Allow microphone',
                      RecoveryAction.openAppSettings => 'Open Settings',
                      _ => 'Continue',
                    }),
                  ),
                ),
                if (!microphoneGranted)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Not now'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaPermissionTile extends StatelessWidget {
  const _MediaPermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.tapHint,
    required this.onTap,
  });

  final Widget icon;
  final String title;
  final String description;
  final bool isGranted;
  final String tapHint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: onTap != null,
      label:
          '$title, ${isGranted ? 'allowed' : 'not allowed'}. $description'
          '${onTap == null ? '' : ' $tapHint'}',
      child: Material(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 10,
              vertical: 12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 24, height: 24, child: Center(child: icon)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
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
                      Text(
                        description,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamilySans,
                          fontSize: 14,
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
          ? const TotemIcon(TotemIcons.checkmark, size: 14, color: Colors.white)
          : null,
    );
  }
}
