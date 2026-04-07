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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final orientation = MediaQuery.orientationOf(context);

    final viewportKind = () {
      if (size.width < 600) {
        return switch (orientation) {
          Orientation.portrait => ViewportKind.smallPortrait,
          Orientation.landscape => ViewportKind.smallLandscape,
        };
      } else {
        return ViewportKind.mediumPlus;
      }
    }();

    return builder(context, viewportKind);
  }
}
