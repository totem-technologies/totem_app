import 'package:flutter/material.dart';

class SpaceGradientMask extends StatelessWidget {
  const SpaceGradientMask({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) {
        final cardHeight = rect.height;
        const gradientHeight = 135.0;
        final startStop = ((cardHeight - gradientHeight) / cardHeight).clamp(
          0.0,
          1.0,
        );
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Colors.transparent, Colors.black],
          stops: [startStop, 1.0],
        ).createShader(
          Rect.fromLTRB(0, 0, rect.width, rect.height),
        );
      },
      blendMode: BlendMode.darken,
      child: child,
    );
  }
}
