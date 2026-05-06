import 'package:flutter/widgets.dart';

enum ViewportKind {
  smallPortrait,
  smallLandscape,
  mediumPlus;

  bool get isLarge => this == smallLandscape || this == mediumPlus;
}

typedef ViewportResolverBuilder =
    Widget Function(
      BuildContext context,
      ViewportKind viewportKind,
    );

class ViewportResolver extends StatelessWidget {
  const ViewportResolver({required this.builder, super.key});

  final ViewportResolverBuilder builder;

  static ViewportKind getViewportKind(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;

    if (shortestSide < 600) {
      final orientation = MediaQuery.orientationOf(context);
      return switch (orientation) {
        Orientation.portrait => ViewportKind.smallPortrait,
        Orientation.landscape => ViewportKind.smallLandscape,
      };
    } else {
      return ViewportKind.mediumPlus;
    }
  }

  @override
  Widget build(BuildContext context) {
    return builder(context, getViewportKind(context));
  }
}
