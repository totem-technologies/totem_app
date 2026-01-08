import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.size = 36.0,
    this.color,
    this.semanticsLabel = 'Loading',
  });

  final Color? color;
  final double size;

  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SizedBox(
        height: size,
        width: size,
        child: CircularProgressIndicator.adaptive(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            color ?? theme.colorScheme.primary,
          ),
          semanticsLabel: semanticsLabel,
        ),
      ),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: LoadingIndicator(),
    );
  }
}
