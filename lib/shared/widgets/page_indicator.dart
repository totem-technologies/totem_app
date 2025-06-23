import 'package:flutter/material.dart';

class PageIndicator extends StatelessWidget {
  const PageIndicator({this.length, this.currentIndex, super.key});

  final int? length;
  final int? currentIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabView = DefaultTabController.of(context);
    final length = this.length ?? tabView.length;
    final currentIndex = this.currentIndex ?? tabView.index;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 5,
      children: List.generate(
        length,
        (index) => Flexible(
          child: Container(
            width: 50,
            height: 8,
            decoration: BoxDecoration(
              color: index <= currentIndex
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}
