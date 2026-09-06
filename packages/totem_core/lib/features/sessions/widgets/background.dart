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
  /// The [Color] passed is the background color the room is rendering.
  static ValueChanged<Color>? onBackgroundChanged;

  @override
  State<RoomBackground> createState() => _RoomBackgroundState();
}

class _RoomBackgroundState extends State<RoomBackground> {
  static const roomDecoration = BoxDecoration(
    color: AppTheme.slate,
  );

  static const gradientColors = <Color>[
    AppTheme.cream,
    AppTheme.mauve,
  ];

  @override
  void didUpdateWidget(covariant RoomBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        RoomBackground.onBackgroundChanged?.call(switch (widget.status) {
          RoomStatus.waitingRoom => gradientColors.reduce(
            (a, b) => Color.lerp(a, b, 0.5)!,
          ),
          _ => roomDecoration.color!,
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: widget.overlayStyle,
      child: ViewportResolver(
        builder: (context, viewportKind) {
          const waitingDecoration = BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: AlignmentDirectional.topCenter,
              end: AlignmentDirectional.bottomCenter,
              stops: [0.5, 1],
            ),
          );

          final foregroundColor = switch (widget.status) {
            RoomStatus.waitingRoom => Colors.black,
            _ => Colors.white,
          };

          return AnimatedContainer(
            duration: kThemeAnimationDuration,
            decoration: switch (widget.status) {
              RoomStatus.waitingRoom => waitingDecoration,
              _ => roomDecoration,
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
