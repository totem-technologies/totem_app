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
    super.key,
  });

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final contentColor = isSelected ? Colors.white : primaryColor;

    return Semantics(
      button: true,
      label: 'My Sessions filter',
      selected: isSelected,
      child: Material(
        color: isSelected ? primaryColor : Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TotemIcon(
                    TotemIcons.mySessions,
                    size: 16,
                    color: contentColor,
                  ),
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
          ),
        ),
      ),
    );
  }
}
