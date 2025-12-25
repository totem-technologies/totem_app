import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    required this.icon,
    required this.onPressed,
    this.margin,
    this.color,
    super.key,
  });

  final String icon;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        margin: margin,
        alignment: AlignmentDirectional.center,
        height: 30,
        width: 30,
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          shape: BoxShape.circle,
        ),
        child: SvgPicture.string(
          icon,
        ),
      ),
    );
  }
}
