import 'package:flutter/material.dart';

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    required this.icon,
    required this.onPressed,
    this.margin,
    this.color,
    super.key,
  });

  final Widget icon;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      alignment: AlignmentDirectional.center,
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: IconButton(
          icon: icon,
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
