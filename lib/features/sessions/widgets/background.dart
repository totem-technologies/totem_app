import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:totem_app/core/config/theme.dart';

class RoomBackground extends StatelessWidget {
  const RoomBackground({
    required this.child,
    this.padding = EdgeInsetsDirectional.zero,
    this.overlayStyle = SystemUiOverlayStyle.light,
    super.key,
  });

  final Widget child;

  final EdgeInsetsGeometry padding;

  final SystemUiOverlayStyle overlayStyle;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: overlayStyle,
      child: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: const [
                  Colors.black,
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
            ),
            padding: padding,
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white),
              child: Theme(
                data: Theme.of(context).copyWith(
                  scaffoldBackgroundColor: Colors.transparent,
                  textTheme: Theme.of(context).textTheme.apply(
                    bodyColor: Colors.white,
                    displayColor: Colors.white,
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
