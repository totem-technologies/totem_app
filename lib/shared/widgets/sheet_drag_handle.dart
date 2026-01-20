import 'package:flutter/material.dart';

class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({
    super.key,
    this.margin = const EdgeInsetsDirectional.only(top: 12, bottom: 14),
  });

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
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
  }
}
