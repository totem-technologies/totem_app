import 'package:flutter/material.dart';
import 'package:totem_core/core/config/theme.dart';

class DaySeparator extends StatelessWidget {
  const DaySeparator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.messageDaySeparatorBg,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.mauve,
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
