import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/media/media_devices_provider.dart';
import 'package:totem_core/features/sessions/media/media_platform.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/shared/totem_icons.dart';

class ActionBarCameraSwitcherButton extends StatefulWidget {
  const ActionBarCameraSwitcherButton({
    required this.isCameraOn,
    required this.onToggle,
    required this.cameraFacing,
    required this.availableCameraDevices,
    required this.selectedCameraDeviceId,
    required this.onCameraFacingChanged,
    this.onCameraDeviceSelected,
    super.key,
  });

  /// Shared capsule around the camera toggle and its device caret.
  static const deviceClusterKey = Key('action-bar-camera-device-cluster');

  final bool isCameraOn;
  final VoidCallback? onToggle;

  final CameraFacing cameraFacing;
  final List<MediaDeviceInfo> availableCameraDevices;
  final String? selectedCameraDeviceId;
  final ValueChanged<CameraFacing> onCameraFacingChanged;
  final ValueChanged<MediaDeviceInfo>? onCameraDeviceSelected;

  @override
  State<ActionBarCameraSwitcherButton> createState() =>
      _ActionBarCameraSwitcherButtonState();
}

class _ActionBarCameraSwitcherButtonState
    extends State<ActionBarCameraSwitcherButton> {
  final _portalController = OverlayPortalController();
  final GlobalKey _buttonKey = GlobalKey();
  var _isOpen = false;

  @override
  void didUpdateWidget(ActionBarCameraSwitcherButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.availableCameraDevices != widget.availableCameraDevices ||
        oldWidget.selectedCameraDeviceId != widget.selectedCameraDeviceId) {
      if (_isOpen) {
        _portalController.hide();
        _isOpen = false;
        // didUpdateWidget runs inside the parent build, so the caret's
        // open color has to refresh on the next frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  void _showCameraPositionOptions() {
    if (_isOpen) return;
    setState(() => _isOpen = true);
    _portalController.show();
  }

  void _dismissOverlay() {
    _portalController.hide();
    if (mounted) setState(() => _isOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopPicker = usesMediaDevicePicker;
    // If the user only has one camera, we show a simple
    // toggle button without the option to switch cameras
    final canChooseBetweenMultipleCameras =
        isDesktopPicker && widget.availableCameraDevices.length > 1;
    if (isDesktopPicker && !canChooseBetweenMultipleCameras) {
      return ActionBarButton(
        semanticsLabel: 'Camera ${widget.isCameraOn ? 'on' : 'off'}',
        // Off is pinkTint, not cream — that's the muted media treatment.
        role: ActionBarButtonRole.media(enabled: widget.isCameraOn),
        onPressed: widget.onToggle,
        child: TotemIcon(
          widget.isCameraOn ? TotemIcons.cameraOn : TotemIcons.cameraOff,
        ),
      );
    }

    return OverlayPortal(
      controller: _portalController,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: (_) {
        final buttonBox =
            _buttonKey.currentContext?.findRenderObject() as RenderBox?;
        if (buttonBox == null) return const SizedBox.shrink();

        return ActionBarCameraSwitcherButtonOverlay(
          buttonKey: _buttonKey,
          isDesktopPicker: isDesktopPicker,
          initialCameraFacing: widget.cameraFacing,
          availableCameraDevices: widget.availableCameraDevices,
          selectedCameraDeviceId: widget.selectedCameraDeviceId,
          onCameraFacingChanged: widget.onCameraFacingChanged,
          onCameraDeviceSelected: widget.onCameraDeviceSelected,
          onDismissOverlay: _dismissOverlay,
        );
      },
      // Caret trails the camera inside one capsule. It used to float in the
      // bar gap, between the mic and the camera, and spin like a collapse
      // control. Pointing up keeps it aimed at the menu that opens above.
      child: _CameraDeviceCluster(
        key: _buttonKey,
        isDesktopPicker: isDesktopPicker,
        menuOpen: _isOpen,
        onOpenDevices: widget.onToggle == null
            ? null
            : _showCameraPositionOptions,
        camera: ActionBarButton(
          semanticsLabel: 'Camera ${widget.isCameraOn ? 'on' : 'off'}',
          onPressed: widget.onToggle,
          role: ActionBarButtonRole.media(enabled: widget.isCameraOn),
          child: TotemIcon(
            widget.isCameraOn ? TotemIcons.cameraOn : TotemIcons.cameraOff,
          ),
        ),
      ),
    );
  }
}

/// Camera toggle plus the device caret, as one control.
///
/// The shared fill is an inset in the action-bar pill, not a second chip.
/// The caret stays smaller than the camera glyph so it reads as an accessory
/// that opens device selection.
class _CameraDeviceCluster extends StatefulWidget {
  const _CameraDeviceCluster({
    required this.camera,
    required this.isDesktopPicker,
    required this.menuOpen,
    required this.onOpenDevices,
    super.key,
  });

  final Widget camera;
  final bool isDesktopPicker;
  final bool menuOpen;
  final VoidCallback? onOpenDevices;

  @override
  State<_CameraDeviceCluster> createState() => _CameraDeviceClusterState();
}

class _CameraDeviceClusterState extends State<_CameraDeviceCluster> {
  var _pressed = false;

  bool get _enabled => widget.onOpenDevices != null;

  @override
  Widget build(BuildContext context) {
    final onLight = ActionBar.onLightBackgroundOf(context);
    final foreground = onLight ? AppTheme.slate : AppTheme.cream;
    // Heavier than the parent pill so the pair separates from the mic,
    // without stacking a lighter glass on top of the bar.
    final fill = onLight
        ? AppTheme.slate.withValues(alpha: 0.16)
        : AppTheme.white.withValues(alpha: 0.14);
    final caretLabel = widget.isDesktopPicker
        ? 'Choose camera'
        : 'Switch camera';
    final caretHint = widget.isDesktopPicker
        ? 'Opens camera selection'
        : 'Switches between front and back camera';

    return DecoratedBox(
      key: ActionBarCameraSwitcherButton.deviceClusterKey,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 2),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              widget.camera,
              Semantics(
                button: true,
                expanded: widget.menuOpen,
                label: caretLabel,
                hint: caretHint,
                enabled: _enabled,
                onTap: widget.onOpenDevices,
                child: MouseRegion(
                  cursor: _enabled
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onOpenDevices,
                    onTapDown: _enabled
                        ? (_) => setState(() => _pressed = true)
                        : null,
                    onTapUp: (_) => setState(() => _pressed = false),
                    onTapCancel: () => setState(() => _pressed = false),
                    child: Tooltip(
                      message: caretLabel,
                      excludeFromSemantics: true,
                      preferBelow: false,
                      child: SizedBox(
                        width: 30,
                        child: Center(
                          child: AnimatedScale(
                            scale: _pressed ? 0.96 : 1,
                            duration: const Duration(milliseconds: 120),
                            curve: Curves.easeOutCubic,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 160),
                              opacity: _enabled ? 1 : 0.4,
                              // The shared glyph points down. Flip it so it
                              // aims at the menu above, instead of reading
                              // as a section that collapses.
                              child: Transform.rotate(
                                angle: math.pi,
                                child: TotemIcon(
                                  TotemIcons.chevronDown,
                                  size: 15,
                                  color: widget.menuOpen
                                      ? AppTheme.mauve
                                      : foreground,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActionBarCameraSwitcherButtonOverlay extends StatefulWidget {
  const ActionBarCameraSwitcherButtonOverlay({
    required this.buttonKey,
    required this.isDesktopPicker,
    required this.initialCameraFacing,
    required this.availableCameraDevices,
    required this.selectedCameraDeviceId,
    required this.onCameraFacingChanged,
    required this.onCameraDeviceSelected,
    required this.onDismissOverlay,
    super.key,
  });

  final GlobalKey buttonKey;
  final bool isDesktopPicker;
  final CameraFacing initialCameraFacing;
  final List<MediaDeviceInfo> availableCameraDevices;
  final String? selectedCameraDeviceId;
  final ValueChanged<CameraFacing> onCameraFacingChanged;
  final ValueChanged<MediaDeviceInfo>? onCameraDeviceSelected;

  final VoidCallback onDismissOverlay;

  @override
  State<ActionBarCameraSwitcherButtonOverlay> createState() =>
      _ActionBarCameraSwitcherButtonOverlayState();
}

class _ActionBarCameraSwitcherButtonOverlayState
    extends State<ActionBarCameraSwitcherButtonOverlay>
    with SingleTickerProviderStateMixin {
  late CameraFacing cameraFacing = widget.initialCameraFacing;
  bool _isDismissing = false;

  static const double buttonWidth = 60;
  static const double buttonsSpacing = 4;

  late final AnimationController _overlayAnimationController =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      );
  late final CurvedAnimation _slideCurve = CurvedAnimation(
    parent: _overlayAnimationController,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slideAnimation = Tween<Offset>(
    begin: const Offset(0, 0.15),
    end: Offset.zero,
  ).animate(_slideCurve);

  @override
  void initState() {
    super.initState();
    _overlayAnimationController.forward();
  }

  @override
  void dispose() {
    _slideCurve.dispose();
    _overlayAnimationController.dispose();
    super.dispose();
  }

  Future<void> _dismissOverlay() async {
    if (_isDismissing) return;
    _isDismissing = true;

    try {
      await _overlayAnimationController.reverse().orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted) {
      widget.onDismissOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final menuContent = widget.isDesktopPicker
        ? Container(
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxWidth: 260),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                if (widget.availableCameraDevices.isEmpty)
                  Text(
                    'No cameras found',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                  )
                else
                  for (final device in widget.availableCameraDevices)
                    _CameraDeviceTile(
                      device: device,
                      isSelected: device.id == widget.selectedCameraDeviceId,
                      onTap: () {
                        widget.onCameraDeviceSelected?.call(device);
                        widget.onDismissOverlay();
                      },
                    ),
              ],
            ),
          )
        : GestureDetector(
            onTap: () {
              setState(() => cameraFacing = cameraFacing.switched);
              widget.onCameraFacingChanged(cameraFacing);
            },
            child: Container(
              constraints: const BoxConstraints(maxHeight: 40, maxWidth: 260),
              padding: const EdgeInsetsDirectional.all(8.0),
              child: Stack(
                alignment: AlignmentDirectional.center,
                children: [
                  const SizedBox(height: 30),
                  AnimatedPositionedDirectional(
                    top: 0,
                    bottom: 0,
                    start: cameraFacing == CameraFacing.front
                        ? 0
                        : buttonWidth + buttonsSpacing,
                    end: cameraFacing == CameraFacing.back
                        ? 0
                        : buttonWidth + buttonsSpacing,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      width: buttonWidth,
                      decoration: BoxDecoration(
                        color: AppTheme.mauve,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  DefaultTextStyle(
                    style: (theme.textTheme.bodyMedium ?? const TextStyle())
                        .copyWith(color: Colors.white),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: buttonsSpacing,
                      children: [
                        SizedBox(
                          width: buttonWidth,
                          child: Center(child: Text('Front')),
                        ),
                        SizedBox(
                          width: buttonWidth,
                          child: Center(child: Text('Back')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );

    final overlayBox = context.findRenderObject() as RenderBox?;
    final buttonBox =
        widget.buttonKey.currentContext?.findRenderObject() as RenderBox?;

    final overlaySize = overlayBox?.size ?? MediaQuery.sizeOf(context);
    final overlayOrigin = overlayBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final buttonGlobalOffset = buttonBox?.localToGlobal(Offset.zero);
    final buttonOffset = buttonGlobalOffset == null
        ? null
        : buttonGlobalOffset - overlayOrigin;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          unawaited(_dismissOverlay());
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _dismissOverlay,
            ),
          ),
          CustomSingleChildLayout(
            delegate: _CameraOverlayPositionDelegate(
              preferredOffset: buttonOffset ?? Offset.zero,
              overlaySize: overlaySize,
            ),
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 8.0),
                child: Material(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(
                    widget.isDesktopPicker ? 20 : 100,
                  ),
                  child: menuContent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraOverlayPositionDelegate extends SingleChildLayoutDelegate {
  _CameraOverlayPositionDelegate({
    required this.preferredOffset,
    required this.overlaySize,
  });

  final Offset preferredOffset;
  final Size overlaySize;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(overlaySize);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Position the menu above the button (bottom of menu at button's top).
    final preferredX = preferredOffset.dx;
    final preferredY = preferredOffset.dy - childSize.height;
    const edgeMargin = 16.0;

    // Keep the menu away from the screen edges. If it is larger than the
    // available space, pin it to the leading edge rather than producing an
    // invalid clamp range.
    final maxX = math.max(
      edgeMargin,
      overlaySize.width - childSize.width - edgeMargin,
    );
    final maxY = math.max(
      edgeMargin,
      overlaySize.height - childSize.height - edgeMargin,
    );
    final clampedX = preferredX.clamp(edgeMargin, maxX);
    final clampedY = preferredY.clamp(edgeMargin, maxY);

    return Offset(clampedX, clampedY);
  }

  @override
  bool shouldRelayout(_CameraOverlayPositionDelegate oldDelegate) {
    return preferredOffset != oldDelegate.preferredOffset ||
        overlaySize != oldDelegate.overlaySize;
  }
}

class _CameraDeviceTile extends StatelessWidget {
  const _CameraDeviceTile({
    required this.device,
    required this.isSelected,
    required this.onTap,
  });

  final MediaDeviceInfo device;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isSelected ? AppTheme.mauve : Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  device.displayLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SessionActionBarCameraButton extends ConsumerStatefulWidget {
  const SessionActionBarCameraButton({required this.session, super.key});

  final SessionController session;

  @override
  ConsumerState<SessionActionBarCameraButton> createState() =>
      _SessionActionBarCameraButtonState();
}

class _SessionActionBarCameraButtonState
    extends ConsumerState<SessionActionBarCameraButton> {
  bool _busy = false;

  Future<void> _toggleCamera(bool isCameraOn) async {
    if (_busy) return;

    final devices = ref.read(
      sessionDeviceControllerProvider(widget.session).notifier,
    );
    setState(() => _busy = true);

    try {
      if (isCameraOn) {
        await devices.disableCamera();
      } else {
        await devices.enableCamera();
      }
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to change camera state from action bar',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = sessionDeviceControllerProvider(widget.session);
    final deviceState = ref.watch(deviceProvider);
    final isCameraOn = deviceState.isCameraOn;
    final onToggle = _busy ? null : () => _toggleCamera(isCameraOn);

    if (!usesMediaDevicePicker) {
      return ActionBarButton(
        semanticsLabel: 'Camera ${isCameraOn ? 'on' : 'off'}',
        role: ActionBarButtonRole.media(enabled: isCameraOn),
        onPressed: onToggle,
        child: TotemIcon(
          isCameraOn ? TotemIcons.cameraOn : TotemIcons.cameraOff,
        ),
      );
    }

    final cameraDevices = ref.watch(cameraDevicesProvider);
    return ActionBarCameraSwitcherButton(
      isCameraOn: isCameraOn,
      onToggle: onToggle,
      cameraFacing: CameraFacing.front,
      availableCameraDevices: cameraDevices,
      selectedCameraDeviceId:
          deviceState.selectedCameraDeviceId ?? cameraDevices.firstOrNull?.id,
      onCameraFacingChanged: (_) {},
      onCameraDeviceSelected: ref
          .read(deviceProvider.notifier)
          .selectCameraDevice,
    );
  }
}
