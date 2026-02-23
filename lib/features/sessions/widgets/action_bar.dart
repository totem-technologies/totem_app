import 'package:flutter/material.dart';
import 'package:totem_app/core/config/theme.dart';

class ActionBarButton extends StatelessWidget {
  const ActionBarButton({
    required this.child,
    required this.onPressed,
    this.semanticsLabel,
    this.square = true,
    this.active = false,
    this.semanticsHint,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool active;
  final bool square;

  final String? semanticsLabel;
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = active ? AppTheme.mauve : AppTheme.white;
    return Semantics(
      button: true,
      label: semanticsLabel,
      hint: semanticsHint,
      enabled: onPressed != null,
      excludeSemantics: semanticsLabel != null,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          decoration: BoxDecoration(
            color: active ? AppTheme.white : AppTheme.mauve,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: foregroundColor),
          ),
          child: Center(
            child: IconTheme.merge(
              data: IconThemeData(
                color: foregroundColor,
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: foregroundColor,
                ),
                child: SizedBox.square(
                  dimension: square ? 24 : null,
                  child: child,
                ),
              ),
            ),
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
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x40000000),
          borderRadius: BorderRadius.circular(30),
        ),
        margin: const EdgeInsetsDirectional.only(bottom: 20),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 20,
            children: [
              for (final child in children) child,
            ],
          ),
        ),
      ),
    );
  }
}
