import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/shared/totem_icons.dart';

class ActionBarCameraSwitcherButton extends StatefulWidget {
  const ActionBarCameraSwitcherButton({
    required this.isCameraOn,
    required this.onToggle,
    required this.cameraPosition,
    required this.availableCameraDevices,
    required this.selectedCameraDeviceId,
    required this.onCameraPositionChanged,
    this.onCameraDeviceSelected,
    super.key,
  });

  final bool isCameraOn;
  final VoidCallback? onToggle;

  final CameraPosition cameraPosition;
  final List<MediaDevice> availableCameraDevices;
  final String? selectedCameraDeviceId;
  final ValueChanged<CameraPosition> onCameraPositionChanged;
  final ValueChanged<MediaDevice>? onCameraDeviceSelected;

  @override
  State<ActionBarCameraSwitcherButton> createState() =>
      _ActionBarCameraSwitcherButtonState();
}

class _ActionBarCameraSwitcherButtonState
    extends State<ActionBarCameraSwitcherButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _menuController;
  OverlayEntry? entry;

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _menuController.dispose();
    entry?.remove();
    super.dispose();
  }

  @override
  void didUpdateWidget(ActionBarCameraSwitcherButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.availableCameraDevices != widget.availableCameraDevices ||
        oldWidget.selectedCameraDeviceId != widget.selectedCameraDeviceId) {
      closeCameraPositionOptions();
    }
  }

  Future<void> showCameraPositionOptions(BuildContext context) {
    final overlay = Overlay.of(context);

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return Future.value();
    final overlaySize = overlay.context.size!;
    final target = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    final position = RelativeRect.fromLTRB(
      target.left,
      target.top,
      overlaySize.width - target.right,
      overlaySize.height - target.bottom,
    );

    final completer = Completer<void>();

    void dismissOverlay() {
      if (entry?.mounted == true) {
        entry?.remove();
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
      entry = null;
    }

    entry = OverlayEntry(
      builder: (context) {
        final isDesktopPicker = kIsWeb || lkPlatformIsDesktop();
        return ActionBarCameraSwitcherButtonOverlay(
          isDesktopPicker: isDesktopPicker,
          initialCameraPosition: widget.cameraPosition,
          availableCameraDevices: widget.availableCameraDevices,
          selectedCameraDeviceId: widget.selectedCameraDeviceId,
          onCameraPositionChanged: widget.onCameraPositionChanged,
          onCameraDeviceSelected: widget.onCameraDeviceSelected,
          onDismissOverlay: dismissOverlay,
          position: Offset(
            position.left,
            overlaySize.height - position.top,
          ),
        );
      },
    );
    overlay.insert(entry!);
    return completer.future;
  }

  Future<void> closeCameraPositionOptions() async {
    await _menuController.reverse();
    entry?.remove();
    entry = null;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopPicker = kIsWeb || lkPlatformIsDesktop();
    // If the user only has one camera, we show a simple
    // toggle button without the option to switch cameras
    final canChooseBetweenMultipleCameras =
        isDesktopPicker && widget.availableCameraDevices.length > 1;
    if (isDesktopPicker && !canChooseBetweenMultipleCameras) {
      return ActionBarButton(
        semanticsLabel: 'Camera ${widget.isCameraOn ? 'on' : 'off'}',
        active: widget.isCameraOn,
        onPressed: widget.onToggle,
        child: TotemIcon(
          widget.isCameraOn ? TotemIcons.cameraOn : TotemIcons.cameraOff,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              _menuController.forward();
              await showCameraPositionOptions(context);
              _menuController.reverse();
            },
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 8.0,
              ),
              child: AnimatedBuilder(
                animation: _menuController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle:
                        CurvedAnimation(
                          parent: _menuController,
                          curve: Curves.easeOutCubic,
                        ).value *
                        math.pi,
                    child: child,
                  );
                },
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          ActionBarButton(
            semanticsLabel: 'Camera ${widget.isCameraOn ? 'on' : 'off'}',
            onPressed: widget.onToggle,
            active: widget.isCameraOn,
            child: TotemIcon(
              widget.isCameraOn ? TotemIcons.cameraOn : TotemIcons.cameraOff,
            ),
          ),
        ],
      ),
    );
  }
}

class ActionBarCameraSwitcherButtonOverlay extends StatefulWidget {
  const ActionBarCameraSwitcherButtonOverlay({
    required this.isDesktopPicker,
    required this.initialCameraPosition,
    required this.availableCameraDevices,
    required this.selectedCameraDeviceId,
    required this.onCameraPositionChanged,
    required this.onCameraDeviceSelected,
    required this.onDismissOverlay,
    required this.position,
    super.key,
  });

  final bool isDesktopPicker;
  final CameraPosition initialCameraPosition;
  final List<MediaDevice> availableCameraDevices;
  final String? selectedCameraDeviceId;
  final ValueChanged<CameraPosition> onCameraPositionChanged;
  final ValueChanged<MediaDevice>? onCameraDeviceSelected;

  final VoidCallback onDismissOverlay;
  final Offset position;

  @override
  State<ActionBarCameraSwitcherButtonOverlay> createState() =>
      _ActionBarCameraSwitcherButtonOverlayState();
}

class _ActionBarCameraSwitcherButtonOverlayState
    extends State<ActionBarCameraSwitcherButtonOverlay>
    with SingleTickerProviderStateMixin {
  late CameraPosition cameraPosition = widget.initialCameraPosition;
  bool _isDismissing = false;

  static const double buttonWidth = 60;
  static const double buttonsSpacing = 4;

  late final AnimationController _overlayAnimationController =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      );
  late final Animation<Offset> _slideAnimation =
      Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _overlayAnimationController,
          curve: Curves.easeOutCubic,
        ),
      );

  @override
  void initState() {
    super.initState();
    _overlayAnimationController.forward();
  }

  @override
  void dispose() {
    _overlayAnimationController.dispose();
    super.dispose();
  }

  Future<void> _dismissOverlay() async {
    if (_isDismissing) return;
    _isDismissing = true;

    await _overlayAnimationController.reverse();
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
                      isSelected:
                          device.deviceId == widget.selectedCameraDeviceId,
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
              cameraPosition = cameraPosition == CameraPosition.front
                  ? CameraPosition.back
                  : CameraPosition.front;
              setState(() {});
              widget.onCameraPositionChanged(cameraPosition);
            },
            child: Padding(
              padding: const EdgeInsetsDirectional.all(8.0),
              child: Stack(
                alignment: AlignmentDirectional.center,
                children: [
                  const SizedBox(height: 30),
                  AnimatedPositionedDirectional(
                    top: 0,
                    bottom: 0,
                    start: cameraPosition == CameraPosition.front
                        ? 0
                        : buttonWidth + buttonsSpacing,
                    end: cameraPosition == CameraPosition.back
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
                        .copyWith(
                          color: Colors.white,
                        ),
                    child: const Row(
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

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _dismissOverlay,
          ),
        ),
        Positioned(
          left: widget.position.dx,
          bottom: widget.position.dy,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 8.0),
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(
                  widget.isDesktopPicker ? 20 : 100,
                ),
                child: menuContent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CameraDeviceTile extends StatelessWidget {
  const _CameraDeviceTile({
    required this.device,
    required this.isSelected,
    required this.onTap,
  });

  final MediaDevice device;
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
                  device.label.isEmpty ? 'Camera' : device.label,
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

class SessionActionBarCameraButton extends StatefulWidget {
  const SessionActionBarCameraButton({
    required this.session,
    required this.participant,
    super.key,
  });

  final SessionController session;
  final LocalParticipant participant;

  @override
  State<SessionActionBarCameraButton> createState() =>
      _SessionActionBarCameraButtonState();
}

class _SessionActionBarCameraButtonState
    extends State<SessionActionBarCameraButton> {
  bool _busy = false;
  List<MediaDevice> _availableCameraDevices = [];
  StreamSubscription<List<MediaDevice>>? _cameraDevicesSubscription;
  EventsListener<ParticipantEvent>? _participantListener;

  @override
  void initState() {
    super.initState();
    _listenToCameraDevices();
    _bindParticipantListener();
  }

  @override
  void didUpdateWidget(covariant SessionActionBarCameraButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant.sid != widget.participant.sid) {
      _bindParticipantListener();
    }
  }

  @override
  void dispose() {
    _cameraDevicesSubscription?.cancel();
    _participantListener?.dispose();
    super.dispose();
  }

  void _bindParticipantListener() {
    _participantListener?.dispose();
    _participantListener = widget.participant.createListener()
      ..on<ParticipantEvent>((_) {
        if (mounted) setState(() {});
      });
  }

  void _listenToCameraDevices() {
    _cameraDevicesSubscription = Hardware.instance.onDeviceChange.stream.listen(
      (devices) {
        if (!mounted) return;
        setState(() {
          _availableCameraDevices = devices
              .where((device) => device.kind == 'videoinput')
              .toList();
        });
      },
    );

    Hardware.instance.videoInputs().then((devices) {
      _availableCameraDevices = devices;
      if (!mounted) return;
      setState(() {});
    });
  }

  TrackPublication<Track>? get _cameraPublication {
    return widget.participant.getTrackPublicationBySource(TrackSource.camera);
  }

  bool get _isCameraEnabled {
    final publication = _cameraPublication;
    if (publication == null) return false;

    final track = publication.track;
    final isMuted = track?.muted ?? publication.muted;
    final isActive = track?.isActive ?? true;
    return isActive && !isMuted;
  }

  Future<void> _toggleCamera() async {
    final session = widget.session;
    final shouldEnable = !_isCameraEnabled;

    setState(() => _busy = true);

    if (shouldEnable) {
      await session.devices.enableCamera();
    } else {
      await session.devices.disableCamera();
    }

    _busy = false;

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final isDesktopPicker = kIsWeb || lkPlatformIsDesktop();

    if (!isDesktopPicker) {
      return ActionBarButton(
        semanticsLabel: 'Camera ${_isCameraEnabled ? 'on' : 'off'}',
        active: _isCameraEnabled,
        onPressed: _busy ? null : _toggleCamera,
        child: TotemIcon(
          _isCameraEnabled ? TotemIcons.cameraOn : TotemIcons.cameraOff,
        ),
      );
    }

    return ActionBarCameraSwitcherButton(
      isCameraOn: _isCameraEnabled,
      onToggle: () async {
        if (_isCameraEnabled) {
          await session.devices.disableCamera();
        } else {
          await session.devices.enableCamera();
        }
        if (mounted) setState(() {});
      },
      cameraPosition: CameraPosition.front,
      availableCameraDevices: _availableCameraDevices,
      selectedCameraDeviceId: session.devices.selectedCameraDeviceId,
      onCameraPositionChanged: (_) {},
      onCameraDeviceSelected: (device) async {
        await session.devices.selectCameraDevice(device);
        if (mounted) setState(() {});
      },
    );
  }
}
