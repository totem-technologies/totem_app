import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:totem_app/shared/totem_icons.dart';

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    required this.icon,
    required this.onPressed,
    this.margin,
    this.color,
    this.tooltip,
    super.key,
  });

  final TotemIconData icon;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
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
          width: 16,
          height: 16,
          colorFilter: const ColorFilter.mode(
            Colors.black,
            BlendMode.srcIn,
          ),
        ),
      ),
    );

    return Center(
      child: Semantics(
        button: true,
        enabled: true,
        child: tooltip != null
            ? Tooltip(
                message: tooltip,
                child: button,
              )
            : button,
      ),
    );
  }
}
