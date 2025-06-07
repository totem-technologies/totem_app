import 'package:flutter/material.dart';

class SpacesFilterBar extends StatelessWidget {
  const SpacesFilterBar({
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    super.key,
  });

  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 56,
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
        margin: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
            children: [
              SpacesFilterChip(
                label: 'All',
                isSelected: selectedCategory == null,
                onTap: () => onCategorySelected(null),
              ),
              ...categories.map(
                (category) => SpacesFilterChip(
                  label: category,
                  isSelected: category == selectedCategory,
                  onTap: () => onCategorySelected(category),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SpacesFilterChip extends StatelessWidget {
  const SpacesFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Center(
        child: GestureDetector(
          onTap: () {
            onTap();
            Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 300),
              alignment: 0.5,
            );
          },
          child: Chip(
            label: Text(label),
            backgroundColor:
                isSelected ? theme.colorScheme.primary : Colors.transparent,
            labelStyle: TextStyle(
              color:
                  isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
            ),
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
          ),
        ),
      ),
    );
  }
}
