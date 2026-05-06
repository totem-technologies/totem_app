import 'package:flutter/material.dart';

class ImageGradientMask extends StatelessWidget {
  const ImageGradientMask({
    required this.child,
    super.key,
    this.gradientHeight = 135.0,
  });

  final Widget child;

  final double gradientHeight;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            height: gradientHeight,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topCenter,
                    end: AlignmentDirectional.bottomCenter,
                    colors: [Colors.transparent, Colors.black],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
