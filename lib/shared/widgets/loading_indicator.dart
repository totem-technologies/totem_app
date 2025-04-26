import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final double size;

  const LoadingIndicator({super.key, this.size = 36.0});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SizedBox(
        height: size,
        width: size,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
        ),
      ),
    );
  }
}
