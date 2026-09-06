import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/more_options_popup.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_camera_button.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_chat_button.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_emoji_button.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_mic_button.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

typedef ActionBarButtonToggleCallback =
    Future<void> Function(bool shouldEnable);

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
// Two named layouts plus a derived width; not a closed token set.
// ignore: use_enums
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

  /// Width the pill needs to sit the given child count at these metrics.
  double widthFor(int childCount) {
    if (childCount <= 0) return 0;
    return childCount * buttonSize +
        (childCount - 1) * gap +
        horizontalPadding * 2;
  }
}

class _ActionBarScope extends InheritedWidget {
  const _ActionBarScope({
    required this.metrics,
    required this.onLightBackground,
    required super.child,
  });

  final _ActionBarMetrics metrics;

  /// Waiting-room / prejoin sits on cream; in-session sits on slate.
  /// Ghost chrome has to flip with that or cream icons vanish on cream.
  final bool onLightBackground;

  static _ActionBarScope? _maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ActionBarScope>();
  }

  static _ActionBarMetrics of(BuildContext context) {
    return _maybeOf(context)?.metrics ?? _ActionBarMetrics.comfortable;
  }

  static bool lightBackgroundOf(BuildContext context) {
    return _maybeOf(context)?.onLightBackground ?? false;
  }

  @override
  bool updateShouldNotify(_ActionBarScope oldWidget) {
    return !identical(metrics, oldWidget.metrics) ||
        onLightBackground != oldWidget.onLightBackground;
  }
}

/// Dark DefaultTextStyle means the surrounding surface is light
/// (RoomBackground waiting-room sets body color to black).
bool _onLightBackground(BuildContext context) {
  final color = DefaultTextStyle.of(context).style.color;
  if (color == null) return false;
  return ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
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
    final onLightBackground = _ActionBarScope.lightBackgroundOf(context);
    final size = metrics.buttonSize;
    final role = widget.role;

    // Don't wash muted/emphasized fills — those colors already mean something.
    final showIdleWash =
        role == ActionBarButtonRole.ghost && _enabled && (_hovered || _pressed);

    // Ghost icons are cream on slate, slate on cream — never cream-on-cream.
    final ghostForeground = onLightBackground ? AppTheme.slate : AppTheme.cream;
    final ghostWash = (onLightBackground ? AppTheme.slate : AppTheme.white)
        .withValues(alpha: 0.16);

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
        background = showIdleWash ? ghostWash : AppTheme.transparent;
        foreground = ghostForeground;
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

  /// Waiting-room chrome (cream gradient) vs in-session slate.
  static bool onLightBackgroundOf(BuildContext context) {
    return _ActionBarScope.lightBackgroundOf(context);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _resolveMetrics(context, constraints);
        final onLightBackground = _onLightBackground(context);

        // 8% white glass disappears on the waiting-room cream gradient.
        final pillFill = onLightBackground
            ? AppTheme.slate.withValues(alpha: 0.12)
            : AppTheme.white.withValues(alpha: 0.08);
        final pillStroke = onLightBackground
            ? AppTheme.slate.withValues(alpha: 0.22)
            : AppTheme.white.withValues(alpha: 0.16);

        return _ActionBarScope(
          metrics: metrics,
          onLightBackground: onLightBackground,
          child: RepaintBoundary(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: pillFill,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: pillStroke, width: 1.5),
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
                      children: [for (final child in children) child],
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

  /// LayoutBuilder reports incoming constraints. A non-flex Row child gets
  /// `maxWidth: infinity`, so we cannot key compact off that alone.
  ///
  /// Phones always compact — landscape prejoin has the least vertical room,
  /// and a 5-button comfortable pill overflows a portrait phone.
  /// Larger viewports use comfortable unless the *finite* constraint (or the
  /// screen width, when unbounded) cannot fit `children.length`.
  _ActionBarMetrics _resolveMetrics(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final viewport = ViewportResolver.getViewportKind(context);
    final isPhone =
        viewport == ViewportKind.smallPortrait ||
        viewport == ViewportKind.smallLandscape;
    if (isPhone) return _ActionBarMetrics.compact;

    final availableWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : MediaQuery.sizeOf(context).width;
    if (availableWidth <
        _ActionBarMetrics.comfortable.widthFor(children.length)) {
      return _ActionBarMetrics.compact;
    }
    return _ActionBarMetrics.comfortable;
  }
}

/// The action bar displayed in the pre join screen.
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
          children: [microphoneButton, cameraButton, chatButton, moreButton],
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
    final session = ref.watch(currentSessionProvider);
    final state = ref.watch(currentSessionStateProvider);
    final sessionEvent = session?.session;
    final canOpen = sessionEvent != null && state != null;
    final tooltip = MaterialLocalizations.of(context).moreButtonTooltip;

    return ExcludeFocus(
      child: Tooltip(
        message: tooltip,
        child: ActionBarButton(
          semanticsLabel: tooltip,
          role: ActionBarButtonRole.sheet(open: _open),
          onPressed: canOpen
              ? () async {
                  setState(() => _open = true);
                  try {
                    await showOptionsSheet(context, state, sessionEvent);
                  } finally {
                    if (mounted) setState(() => _open = false);
                  }
                }
              : null,
          child: const TotemIcon(TotemIcons.more),
        ),
      ),
    );
  }
}
