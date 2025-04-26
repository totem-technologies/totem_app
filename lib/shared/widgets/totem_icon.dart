import 'package:flutter/material.dart';

class TotemIcon extends StatelessWidget {
  final double? size;

  const TotemIcon({super.key, this.size});

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
