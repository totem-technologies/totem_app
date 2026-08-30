import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/more_options_popup.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_camera_button.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_chat_button.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_emoji_button.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_mic_button.dart';
import 'package:totem_core/shared/totem_icons.dart';

typedef ActionBarButtonToggleCallback =
    Future<void> Function(bool shouldEnable);

// Below this width, five 78px buttons overflow a phone.
const double _kCompactWidth = 456;

/// ghost = idle, muted = media off, emphasized = open sheet.
/// Keep muted and emphasized distinct — camera-off is not "sheet open".
enum ActionBarButtonRole {
  ghost,
  muted,
  emphasized;

  static ActionBarButtonRole media({required bool enabled}) {
    return enabled ? ghost : muted;
  }

  static ActionBarButtonRole sheet({required bool open}) {
    return open ? emphasized : ghost;
  }
}

@immutable
class _ActionBarMetrics {
  const _ActionBarMetrics({
    required this.buttonSize,
    required this.iconSize,
    required this.gap,
    required this.horizontalPadding,
    required this.verticalPadding,
  });

  static const comfortable = _ActionBarMetrics(
    buttonSize: 78,
    iconSize: 39,
    gap: 10,
    horizontalPadding: 13,
    verticalPadding: 13,
  );

  static const compact = _ActionBarMetrics(
    buttonSize: 48,
    iconSize: 24,
    gap: 6,
    horizontalPadding: 8,
    verticalPadding: 8,
  );

  final double buttonSize;
  final double iconSize;
  final double gap;
  final double horizontalPadding;
  final double verticalPadding;

  @override
  bool operator ==(Object other) {
    return other is _ActionBarMetrics &&
        buttonSize == other.buttonSize &&
        iconSize == other.iconSize &&
        gap == other.gap &&
        horizontalPadding == other.horizontalPadding &&
        verticalPadding == other.verticalPadding;
  }

  @override
  int get hashCode => Object.hash(
    buttonSize,
    iconSize,
    gap,
    horizontalPadding,
    verticalPadding,
  );
}

class _ActionBarScope extends InheritedWidget {
  const _ActionBarScope({
    required this.metrics,
    required super.child,
  });

  final _ActionBarMetrics metrics;

  static _ActionBarMetrics of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_ActionBarScope>()
            ?.metrics ??
        _ActionBarMetrics.comfortable;
  }

  @override
  bool updateShouldNotify(_ActionBarScope oldWidget) {
    return metrics != oldWidget.metrics;
  }
}

class ActionBarButton extends StatefulWidget {
  const ActionBarButton({
    required this.child,
    required this.onPressed,
    this.semanticsLabel,
    this.square = true,
    this.role = ActionBarButtonRole.ghost,
    this.semanticsHint,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;

  final ActionBarButtonRole role;
  final bool square;

  final String? semanticsLabel;
  final String? semanticsHint;

  @override
  State<ActionBarButton> createState() => _ActionBarButtonState();
}

class _ActionBarButtonState extends State<ActionBarButton> {
  var _hovered = false;
  var _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _ActionBarScope.of(context);
    final size = metrics.buttonSize;
    final role = widget.role;

    // Don't wash muted/emphasized fills — those colors already mean something.
    final showIdleWash =
        role == ActionBarButtonRole.ghost && _enabled && (_hovered || _pressed);

    final Color background;
    final Color foreground;
    switch (role) {
      case ActionBarButtonRole.muted:
        background = AppTheme.pinkTint;
        foreground = AppTheme.cream;
      case ActionBarButtonRole.emphasized:
        background = AppTheme.cream;
        foreground = AppTheme.slate;
      case ActionBarButtonRole.ghost:
        background = showIdleWash
            ? AppTheme.white.withValues(alpha: 0.16)
            : AppTheme.transparent;
        foreground = AppTheme.cream;
    }

    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      hint: widget.semanticsHint,
      enabled: _enabled,
      excludeSemantics: widget.semanticsLabel != null,
      child: MouseRegion(
        cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => _setHovered(true),
        onExit: (_) {
          _setHovered(false);
          _setPressed(false);
        },
        child: GestureDetector(
          // Unfilled ghost circles still need a hit target.
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapUp: _enabled ? (_) => _setPressed(false) : null,
          onTapCancel: _enabled ? () => _setPressed(false) : null,
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: _enabled ? 1 : 0.4,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: IconTheme.merge(
                    data: IconThemeData(
                      color: foreground,
                      size: metrics.iconSize,
                    ),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(color: foreground),
                      child: SizedBox.square(
                        dimension: widget.square ? metrics.iconSize : null,
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ActionBar extends StatelessWidget {
  const ActionBar({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = constraints.maxWidth < _kCompactWidth
            ? _ActionBarMetrics.compact
            : _ActionBarMetrics.comfortable;

        return _ActionBarScope(
          metrics: metrics,
          child: RepaintBoundary(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppTheme.white.withValues(alpha: 0.16),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: metrics.horizontalPadding,
                    vertical: metrics.verticalPadding,
                  ),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: metrics.gap,
                      children: [
                        for (final child in children) child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class PrejoinActionBar extends StatefulWidget {
  const PrejoinActionBar({
    required this.locked,
    required this.previewAudioTrack,
    required this.onToggleMic,
    required this.isSpeakerOn,
    required this.onToggleSpeaker,
    required this.isCameraOn,
    required this.onToggleCamera,
    required this.cameraPosition,
    required this.selectedCameraDeviceId,
    required this.onCameraPositionChanged,
    required this.onCameraDeviceSelected,
    super.key,
  });

  final bool locked;
  final LocalAudioTrack? previewAudioTrack;
  final AsyncCallback onToggleMic;
  final bool isSpeakerOn;
  final VoidCallback onToggleSpeaker;
  final bool isCameraOn;
  final VoidCallback onToggleCamera;
  final CameraPosition cameraPosition;
  final String? selectedCameraDeviceId;
  final ValueChanged<CameraPosition> onCameraPositionChanged;
  final ValueChanged<MediaDevice> onCameraDeviceSelected;

  @override
  State<PrejoinActionBar> createState() => _PrejoinActionBarState();
}

class _PrejoinActionBarState extends State<PrejoinActionBar> {
  List<MediaDevice> _availableCameraDevices = [];
  StreamSubscription<List<MediaDevice>>? _cameraDevicesSubscription;

  @override
  void initState() {
    super.initState();
    _listenToCameraDevices();
  }

  @override
  void dispose() {
    _cameraDevicesSubscription?.cancel();
    super.dispose();
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
      if (!mounted) return;
      setState(() {
        _availableCameraDevices = devices;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ActionBar(
      key: SessionActionBar.actionBarKey,
      children: [
        ActionBarMicButton(
          participant: null,
          audioTrack: widget.previewAudioTrack,
          onToggle: !widget.locked ? (v) async => widget.onToggleMic() : null,
        ),
        // ActionBarSpeakerButton(
        //   isSpeakerOn: widget.isSpeakerOn,
        //   onSpeakerToggled: widget.locked
        //       ? null
        //       : (v) => widget.onToggleSpeaker(),
        // ),
        ActionBarCameraSwitcherButton(
          isCameraOn: widget.isCameraOn,
          onToggle: widget.locked ? null : widget.onToggleCamera,
          cameraPosition: widget.cameraPosition,
          availableCameraDevices: _availableCameraDevices,
          selectedCameraDeviceId:
              widget.selectedCameraDeviceId ??
              _availableCameraDevices.firstOrNull?.deviceId,
          onCameraPositionChanged: widget.onCameraPositionChanged,
          onCameraDeviceSelected: widget.onCameraDeviceSelected,
        ),
      ],
    );
  }
}

class SessionActionBar extends ConsumerWidget {
  const SessionActionBar({super.key});

  static final GlobalKey actionBarKey = GlobalKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final currentScreen = ref.watch(resolveCurrentScreenProvider);
    final user = session?.room?.localParticipant;

    if (session == null || currentScreen == null || user == null) {
      return const SizedBox.shrink();
    }

    final microphoneButton = ActionBarMicButton(
      participant: user,
      onToggle: (shouldEnable) async {
        if (shouldEnable) {
          await session.devices.enableMicrophone();
        } else {
          await session.devices.disableMicrophone();
        }
      },
    );

    final cameraButton = SessionActionBarCameraButton(
      session: session,
      participant: user,
    );

    final emojiBarButton = ActionBarEmojiButton(
      onEmojiSelected: (emoji) {
        session.messaging.sendReaction(emoji);
      },
    );

    const chatButton = ActionBarChatButton();
    const moreButton = _ActionBarMoreButton();

    switch (currentScreen) {
      case RoomScreen.error:
      case RoomScreen.disconnected:
      case RoomScreen.loading:
        return const SizedBox.shrink();
      case RoomScreen.listening:
        return ActionBar(
          key: SessionActionBar.actionBarKey,
          children: [
            microphoneButton,
            cameraButton,
            emojiBarButton,
            chatButton,
            moreButton,
          ],
        );
      case RoomScreen.speaking:
      case RoomScreen.passing:
      case RoomScreen.receiving:
        return ActionBar(
          key: SessionActionBar.actionBarKey,
          children: [
            microphoneButton,
            cameraButton,
            chatButton,
            moreButton,
          ],
        );
    }
  }
}

class _ActionBarMoreButton extends ConsumerStatefulWidget {
  const _ActionBarMoreButton();

  @override
  ConsumerState<_ActionBarMoreButton> createState() =>
      _ActionBarMoreButtonState();
}

class _ActionBarMoreButtonState extends ConsumerState<_ActionBarMoreButton> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: ActionBarButton(
        semanticsLabel: MaterialLocalizations.of(context).moreButtonTooltip,
        role: ActionBarButtonRole.sheet(open: _open),
        onPressed: () async {
          final session = ref.read(currentSessionProvider);
          final state = ref.read(currentSessionStateProvider);
          if (session?.session == null || state == null) return;

          setState(() => _open = true);
          await showOptionsSheet(context, state, session!.session!);
          if (mounted) setState(() => _open = false);
        },
        child: const TotemIcon(TotemIcons.more),
      ),
    );
  }
}
