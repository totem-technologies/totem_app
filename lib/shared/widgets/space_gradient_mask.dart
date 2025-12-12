import 'package:flutter/material.dart';

class SpaceGradientMask extends StatelessWidget {
  const SpaceGradientMask({
    required this.child,
    super.key,
    this.gradientHeight = 135.0,
  });

  final Widget child;

  final double gradientHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: gradientHeight,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
