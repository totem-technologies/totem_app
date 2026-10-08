import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/controllers/features/permissions_controller.dart';
import 'package:totem_core/features/sessions/widgets/action_slider_button.dart';
import 'package:totem_core/features/sessions/widgets/permissions_browser.dart'
    as browser;
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/sheet_drag_handle.dart';

Future<void> showBackgroundActivityDialog(BuildContext context) async {
  if (kIsWeb || kIsWasm) {
    // Background mode isn't relevant on web, so we can skip showing the dialog.
    return;
  }
  final isIgnored = await FlutterForegroundTask.isIgnoringBatteryOptimizations;

  if (isIgnored || !context.mounted) {
    return;
  }

  return await showDialog<void>(
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

/// Shows browser-specific recovery instructions when web permissions are denied.
///
/// Returns true if permissions were granted after retrying. Native platforms do
/// not show this dialog.
Future<bool> showWebPermissionsDeniedDialog(
  BuildContext context, {
  AsyncValueGetter<bool>? retryPermissions,
}) async {
  if (!(kIsWeb || kIsWasm) || !context.mounted) return false;

  final container = ProviderScope.containerOf(context, listen: false);
  final permissionsGranted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _WebPermissionsDeniedDialog(
      instructions: _permissionsInstructions(),
      onCheckAgain: () async {
        if (retryPermissions != null) return await retryPermissions();

        // Legacy callers use the permissions controller. The session pre-join
        // flow supplies [retryPermissions] to refresh the real preview tracks.
        final controller = container.read(
          permissionsControllerProvider.notifier,
        );
        await controller.requestPermissions();
        return (await controller.currentStatuses).requiredPermissionsGranted;
      },
    ),
  );

  if (!context.mounted) return false;
  if (permissionsGranted == true) return true;

  if (context.canPop()) context.pop();
  return false;
}

class _PermissionInstructions {
  const _PermissionInstructions({
    required this.browser,
    required this.steps,
    required this.helper,
  });

  final String browser;
  final List<String> steps;
  final String helper;
}

_PermissionInstructions _permissionsInstructions() {
  final userAgent = browser.permissionsBrowserUserAgent;
  final platform = defaultTargetPlatform;
  final isMac = platform == TargetPlatform.macOS;
  final isWindows = platform == TargetPlatform.windows;
  final isAndroid = platform == TargetPlatform.android;
  final isIOS = platform == TargetPlatform.iOS;

  // Edge
  if (userAgent.contains('Edg/') ||
      userAgent.contains('EdgA/') ||
      userAgent.contains('EdgiOS/')) {
    return _PermissionInstructions(
      browser: 'Edge',
      steps: const [
        'Click the lock icon beside the web address.',
        'Open Permissions for this site.',
        'Set Microphone and Camera to Allow, then reload.',
      ],
      helper: isWindows
          ? 'Still blocked? On Windows, open Settings → Privacy → Microphone (and Camera) and let desktop apps use them.'
          : isMac
          ? 'Still blocked? On macOS, open System Settings → Privacy & Security → Microphone (and Camera) and turn on Edge.'
          : 'Still blocked? Check your device settings and allow Edge to use the microphone and camera.',
    );
  }
  // Firefox
  if (userAgent.contains('Firefox/') || userAgent.contains('FxiOS/')) {
    return const _PermissionInstructions(
      browser: 'Firefox',
      steps: [
        'Click the crossed-out microphone and camera icon in the address bar.',
        'Click the ✕ beside “Blocked Temporarily”.',
        'Reload the page and choose Allow when asked.',
      ],
      helper:
          'Firefox forgets temporary blocks on reload, a refresh is often all it takes.',
    );
  }
  // Safari
  if (userAgent.contains('Safari/') &&
      !userAgent.contains('Chrome/') &&
      !userAgent.contains('CriOS/')) {
    return _PermissionInstructions(
      browser: 'Safari',
      steps: isIOS
          ? const [
              'Tap the aA button in the address bar → Website Settings.',
              'Set Microphone and Camera to Allow.',
              "Reload the page, we'll bring you straight back here.",
            ]
          : const [
              'Open the Safari menu → Settings for This Website…',
              'Set Microphone and Camera to Allow.',
              "Reload the page, we'll bring you straight back here.",
            ],
      helper: isMac
          ? 'Still blocked? Open System Settings → Privacy & Security → Microphone (and Camera) and turn on Safari.'
          : isIOS
          ? 'Still blocked? Open Settings → Safari → Camera and Microphone and allow access.'
          : 'Still blocked? Check your device privacy settings and allow Safari to use the microphone and camera.',
    );
  }

  // Chrome
  return _PermissionInstructions(
    browser: 'Chrome',
    steps: const [
      'Click the lock icon at the left of the address bar.',
      'Switch Microphone and Camera to Allow.',
      "Reload the page, we'll bring you straight back here.",
    ],
    helper: isMac
        ? 'Still blocked? On macOS, open System Settings → Privacy & Security → microphone and camera and turn on Chrome.'
        : isWindows
        ? 'Still blocked? On Windows, open Settings → Privacy → Microphone (and Camera) and let desktop apps use them.'
        : isAndroid
        ? 'Still blocked? Open Android Settings → Apps → Chrome → Permissions and allow the microphone and camera.'
        : 'Still blocked? Check your device privacy settings and allow Chrome to use the microphone and camera.',
  );
}

class _WebPermissionsDeniedDialog extends StatefulWidget {
  const _WebPermissionsDeniedDialog({
    required this.instructions,
    required this.onCheckAgain,
  });

  final _PermissionInstructions instructions;
  final AsyncValueGetter<bool> onCheckAgain;

  @override
  State<_WebPermissionsDeniedDialog> createState() =>
      _WebPermissionsDeniedDialogState();
}

class _WebPermissionsDeniedDialogState
    extends State<_WebPermissionsDeniedDialog> {
  Future<bool> _checkAgain() async {
    try {
      final granted = await widget.onCheckAgain();
      if (granted && mounted) Navigator.of(context).pop(true);
      return granted;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to check permissions again',
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final instructions = widget.instructions;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: 14,
            horizontal: 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 18,
            children: [
              Column(
                spacing: 5,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  Text(
                    'Your browser is still blocking us',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'It needs to be changed in ${instructions.browser}. Three quick steps:',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge,
                  ),
                ],
              ),
              for (var index = 0; index < instructions.steps.length; index++)
                _PermissionStep(
                  number: index + 1,
                  text: instructions.steps[index],
                ),
              Text(
                instructions.helper,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              Center(
                child: ActionButton(
                  onActionCompleted: _checkAgain,
                  text: 'Check again',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionStep extends StatelessWidget {
  const _PermissionStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      spacing: 12,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          child: Center(child: Text('$number', textAlign: TextAlign.center)),
        ),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
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
  } catch (error) {
    // Fall back to showing the sheet if the initial permission read fails.
  }

  if (kIsWeb || kIsWasm) {
    try {
      final permissions = container.read(
        permissionsControllerProvider.notifier,
      );
      await permissions.requestPermissions();

      return (await permissions.currentStatuses).requiredPermissionsGranted;
    } catch (error) {
      // If checking web permissions fails, we'll show the sheet as a fallback.
    }
    return false;
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
          return const SafeArea(child: PermissionsRequestSheet());
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
                  icon: const TotemIcon(TotemIcons.notification, size: 25),
                  title: 'Notification',
                  description:
                      'Allow Totem to send you notifications about sessions, '
                      'new blogs, and more',
                  isGranted: permissionsState?.isNotificationGranted ?? false,
                  onTap: controller.requestNotification,
                ),
                const SizedBox(height: 10),
                PermissionItemTile(
                  icon: const TotemIcon(TotemIcons.microphoneOn, size: 25),
                  title: 'Mic',
                  description:
                      'To speak during sessions, Totem needs access to your '
                      'microphone.',
                  isGranted: permissionsState?.isMicrophoneGranted ?? false,
                  onTap: controller.requestMicrophone,
                ),
                const SizedBox(height: 10),
                PermissionItemTile(
                  icon: const TotemIcon(TotemIcons.cameraOn, size: 25),
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
