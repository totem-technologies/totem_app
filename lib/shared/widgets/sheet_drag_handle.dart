import 'package:flutter/material.dart';
import 'package:totem_app/shared/widgets/viewport_resolver.dart';

class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({
    super.key,
    this.margin = const EdgeInsetsDirectional.only(top: 20, bottom: 20),
  });

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return ViewportResolver(
      builder: (context, viewportKind) {
        switch (viewportKind) {
          case ViewportKind.smallPortrait:
          case ViewportKind.smallLandscape:
            return Center(
              child: Container(
                margin: margin,
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          case ViewportKind.mediumPlus:
            return SizedBox(height: margin.vertical / 2);
        }
      },
    );
  }
}
