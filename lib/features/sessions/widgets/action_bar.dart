import 'package:flutter/material.dart';
import 'package:totem_app/core/config/theme.dart';

class ActionBarButton extends StatelessWidget {
  const ActionBarButton({
    required this.child,
    required this.onPressed,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        decoration: BoxDecoration(
          color: AppTheme.mauve,
          // shape: BoxShape.circle,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white),
        ),
        child: Center(
          child: IconTheme.merge(
            data: const IconThemeData(color: Colors.white),
            child: child,
          ),
        ),
      ),
    );
  }
}

class ActionBar extends StatelessWidget {
  const ActionBar({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x40000000),
        borderRadius: BorderRadius.circular(30),
      ),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 10,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 20,
        children: [
          for (final child in children) child,
        ],
      ),
    );
  }
}
