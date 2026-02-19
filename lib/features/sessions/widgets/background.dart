import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/core/config/theme.dart';

class RoomBackground extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: overlayStyle,
      child: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;

          final waitingDecoration = BoxDecoration(
            gradient: LinearGradient(
              colors: const [
                AppTheme.cream,
                AppTheme.mauve,
              ],
              begin: isLandscape
                  ? AlignmentDirectional.centerStart
                  : AlignmentDirectional.topCenter,
              end: isLandscape
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.bottomCenter,
              stops: const [0.5, 1],
            ),
          );
          const roomDecoration = BoxDecoration(
            color: AppTheme.slate,
          );

          final foregroudColor = switch (status) {
            RoomStatus.waitingRoom => Colors.black,
            _ => Colors.white,
          };
          return AnimatedContainer(
            duration: kThemeAnimationDuration,
            decoration: switch (status) {
              RoomStatus.waitingRoom => waitingDecoration,
              _ => roomDecoration,
            },
            padding: padding,
            child: DefaultTextStyle(
              style: TextStyle(color: foregroudColor),
              child: Theme(
                data: Theme.of(context).copyWith(
                  scaffoldBackgroundColor: Colors.transparent,
                  textTheme: Theme.of(context).textTheme.apply(
                    bodyColor: foregroudColor,
                    displayColor: foregroudColor,
                    decorationColor: foregroudColor,
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
