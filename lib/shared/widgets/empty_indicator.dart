import 'package:flutter/material.dart';
import 'package:totem_app/shared/totem_icons.dart';

class EmptyIndicator extends StatelessWidget {
  const EmptyIndicator({
    super.key,
    this.text,
    this.icon = TotemIcons.lock,
    this.onRetry,
  });

  final String? text;
  final TotemIconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TotemIcon(icon, size: 80),
          const SizedBox(height: 16),
          Text(text ?? 'Nothing available yet'),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                fixedSize: const Size(120, 42),
                minimumSize: Size.zero,
                padding: EdgeInsetsDirectional.zero,
              ),
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}
