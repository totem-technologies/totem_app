import 'package:flutter/material.dart';
import 'package:totem_app/core/config/theme.dart';

class RoomBackground extends StatelessWidget {
  const RoomBackground({
    required this.child,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: child,
    );
  }
}
