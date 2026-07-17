import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';
import 'package:totem_core/shared/logger.dart';

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
    logger.i('hi');
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: ViewportResolver(
        builder: (context, viewportKind) {
          final waitingDecoration = BoxDecoration(
            gradient: LinearGradient(
              colors: const [
                AppTheme.cream,
                AppTheme.mauve,
              ],
              begin: switch (viewportKind) {
                ViewportKind.smallLandscape => AlignmentDirectional.centerStart,
                _ => AlignmentDirectional.topCenter,
              },
              end: switch (viewportKind) {
                ViewportKind.smallLandscape => AlignmentDirectional.centerEnd,
                _ => AlignmentDirectional.bottomCenter,
              },
              stops: const [0.5, 1],
            ),
          );
          const roomDecoration = BoxDecoration(
            color: AppTheme.slate,
          );

          final foregroundColor = switch (status) {
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
