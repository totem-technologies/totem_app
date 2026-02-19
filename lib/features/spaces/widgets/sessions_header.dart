import 'package:flutter/material.dart';
import 'package:totem_app/shared/totem_icons.dart';

class SessionsHeader extends StatelessWidget {
  const SessionsHeader({
    required this.onMySessionsTapped,
    super.key,
    this.isMySessionsSelected = false,
  });

  final VoidCallback onMySessionsTapped;
  final bool isMySessionsSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20).copyWith(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Sessions',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          MySessionsButton(
            isSelected: isMySessionsSelected,
            onTap: onMySessionsTapped,
          ),
        ],
      ),
    );
  }
}

class MySessionsButton extends StatelessWidget {
  const MySessionsButton({
    required this.isSelected,
    required this.onTap,
    this.iconOnly = false,
    super.key,
  });

  final bool isSelected;
  final VoidCallback onTap;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final contentColor = isSelected ? Colors.white : primaryColor;

    return Semantics(
      button: true,
      label: 'My Sessions filter',
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: iconOnly ? 10 : 16,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TotemIcon(
                TotemIcons.mySessions,
                size: 16,
                color: contentColor,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: iconOnly
                    ? const SizedBox.shrink()
                    : Row(
                        children: [
                          const SizedBox(width: 8),
                          Text(
                            'My Sessions',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: contentColor,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
