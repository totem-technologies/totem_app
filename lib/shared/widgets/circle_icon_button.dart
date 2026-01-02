import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:totem_app/shared/totem_icons.dart';

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    required this.icon,
    required this.onPressed,
    this.margin,
    this.color,
    super.key,
  });

  final TotemIconData icon;
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
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            end: icon == TotemIcons.arrowBack ? 2 : 0,
          ),
          child: SvgPicture.string(
            icon,
            width: 16,
            height: 16,
            colorFilter: const ColorFilter.mode(
              Colors.black,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
