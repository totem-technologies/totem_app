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
    return Container(
      height: 56,
      constraints: const BoxConstraints(maxWidth: 500),
      margin: const EdgeInsetsDirectional.only(
        top: 8,
        bottom: 8,
        start: 16,
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
        borderRadius: BorderRadius.circular(50),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: Stack(
          children: [
            Material(
              type: MaterialType.transparency,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 16,
                ),
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
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 28,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(50),
                    bottomRight: Radius.circular(50),
                  ),
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.centerEnd,
                    end: AlignmentDirectional.centerStart,
                    stops: const [
                      0,
                      0.2,
                      1,
                    ],
                    colors: [
                      Colors.white,
                      Colors.white,
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 16,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(50),
                    bottomLeft: Radius.circular(50),
                  ),
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    stops: const [
                      0.5,
                      1,
                    ],
                    colors: [
                      Colors.white,
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
          onTap: () async {
            onTap();
            await Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 300),
              alignment: 0.5,
            );
          },
          child: Chip(
            label: Text(label),
            backgroundColor: isSelected
                ? theme.colorScheme.primary
                : Colors.transparent,
            labelStyle: TextStyle(
              color: isSelected
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
