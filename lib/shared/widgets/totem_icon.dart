import 'package:flutter/material.dart';
import 'package:totem_app/shared/assets.dart';

class TotemIconLogo extends StatelessWidget {
  const TotemIconLogo({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final size = this.size ?? IconTheme.of(context).size;
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        TotemAssets.logoLarge,
        width: size,
        height: size,
        color: color,
      ),
    );
  }
}

class TotemLogo extends StatelessWidget {
  const TotemLogo({
    super.key,
    this.size,
    this.color,
  });

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      child: Image.asset(
        TotemAssets.logoSmall,
        fit: BoxFit.contain,
        color: color,
      ),
    );
  }
}
