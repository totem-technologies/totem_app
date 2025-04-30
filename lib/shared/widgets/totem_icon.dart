import 'package:flutter/material.dart';

class TotemIcon extends StatelessWidget {
  const TotemIcon({super.key, this.size});
  final double? size;

  @override
  Widget build(BuildContext context) {
    final size = this.size ?? IconTheme.of(context).size;
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        'assets/logo/logo-square-black-512.png',
        width: size,
        height: size,
      ),
    );
  }
}

class TotemLogo extends StatelessWidget {
  const TotemLogo({super.key, this.size});
  final double? size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      child: Image.asset(
        'assets/logo/logo-black-small.png',
        fit: BoxFit.contain,
      ),
    );
  }
}
