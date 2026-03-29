import 'package:flutter/material.dart';
import 'package:totem_app/core/config/theme.dart';

class PermissionItemTile extends StatelessWidget {
  const PermissionItemTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onTap,
    super.key,
  });

  final Widget icon;
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cream,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: isGranted ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icon,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamilySans,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamilySans,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _CircleCheckbox(isChecked: isGranted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleCheckbox extends StatelessWidget {
  const _CircleCheckbox({required this.isChecked});

  final bool isChecked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isChecked ? AppTheme.mauve : Colors.transparent,
        border: isChecked ? null : Border.all(color: AppTheme.gray, width: 1.5),
      ),
      child: isChecked
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}
