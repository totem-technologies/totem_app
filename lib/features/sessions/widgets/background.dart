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
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black,
              AppTheme.mauve,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.5, 1],
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
      ),
    );
  }
}
