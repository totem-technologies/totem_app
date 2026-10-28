import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

class RoomBackground extends StatefulWidget {
  const RoomBackground({
    required this.child,
    this.padding = EdgeInsetsDirectional.zero,
    this.overlayStyle = SystemUiOverlayStyle.light,
    this.status = RoomStatus.waitingRoom,
    super.key,
  });

  final Widget child;

  /// The padding to apply around the child widget.
  final EdgeInsetsGeometry padding;

  /// The system UI overlay style to apply.
  final SystemUiOverlayStyle overlayStyle;

  /// The status of the session to determine background style.
  final RoomStatus status;

  /// Called when the room background changes so platform-specific
  /// code (e.g. web) can sync the native chrome to avoid white flashes.
  ///
  /// The [BoxDecoration] passed is the background decoration the room is rendering.
  /// When the last [RoomBackground] leaves the tree, this is invoked with
  /// [defaultPageDecoration] so non-room routes don't keep the room colour.
  static ValueChanged<BoxDecoration>? onBackgroundChanged;

  /// Waiting-room cream → mauve gradient. Synced to the page chrome on web.
  static const waitingDecoration = BoxDecoration(
    gradient: LinearGradient(
      colors: [AppTheme.cream, AppTheme.waitingRoomMauve],
      begin: AlignmentDirectional.topCenter,
      end: AlignmentDirectional.bottomCenter,
      stops: [0.5, 1],
    ),
  );

  /// In-session slate fill.
  static const roomDecoration = BoxDecoration(color: AppTheme.slate);

  /// Restored when the last [RoomBackground] unmounts. Matches [AppTheme.cream]
  /// / `packages/totem_web/web/index.html`.
  static const defaultPageDecoration = BoxDecoration(color: AppTheme.cream);

  @override
  State<RoomBackground> createState() => _RoomBackgroundState();
}

class _RoomBackgroundState extends State<RoomBackground> {
  /// Live [RoomBackground] instances. Only the last one out restores cream,
  /// so a replacement room (pre-join → session) doesn't flash the default
  /// page colour from the outgoing widget's [dispose].
  static var _activeCount = 0;

  @override
  void initState() {
    super.initState();
    _activeCount++;
    _notifyBackgroundChanged();
  }

  @override
  void didUpdateWidget(covariant RoomBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status) {
      _notifyBackgroundChanged();
    }
  }

  @override
  void dispose() {
    _activeCount--;
    // Restore cream synchronously. A post-frame here would race a newly
    // mounted room (its notify is already scheduled) and the [mounted]
    // guard on [_notifyBackgroundChanged] would skip work we *do* want:
    // clearing slate/gradient once nothing in the tree owns the chrome.
    if (_activeCount == 0) {
      RoomBackground.onBackgroundChanged?.call(
        RoomBackground.defaultPageDecoration,
      );
    }
    super.dispose();
  }

  void _notifyBackgroundChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      RoomBackground.onBackgroundChanged?.call(switch (widget.status) {
        RoomStatus.waitingRoom => RoomBackground.waitingDecoration,
        _ => RoomBackground.roomDecoration,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: widget.overlayStyle,
      child: ViewportResolver(
        builder: (context, viewportKind) {
          final foregroundColor = switch (widget.status) {
            RoomStatus.waitingRoom => Colors.black,
            _ => Colors.white,
          };

          return AnimatedContainer(
            duration: kThemeAnimationDuration,
            decoration: switch (widget.status) {
              RoomStatus.waitingRoom => RoomBackground.waitingDecoration,
              _ => RoomBackground.roomDecoration,
            },
            padding: widget.padding,
            child: Theme(
              data: Theme.of(context).copyWith(
                scaffoldBackgroundColor: Colors.transparent,
                textTheme: Theme.of(context).textTheme.apply(
                  bodyColor: foregroundColor,
                  displayColor: foregroundColor,
                  decorationColor: foregroundColor,
                ),
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: foregroundColor),
                child: Material(
                  type: MaterialType.transparency,
                  child: widget.child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
