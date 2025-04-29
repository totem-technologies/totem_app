import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/models/space_detail_schema.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/features/spaces/widgets/space_card.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/totem_icon.dart';

// Provider to track the selected category filter
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

class SpacesDiscoveryScreen extends ConsumerWidget {
  const SpacesDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaces = ref.watch(listSpacesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return Scaffold(
      appBar: AppBar(title: const TotemLogo(size: 24)),
      body: spaces.when(
        data: (spacesList) {
          if (spacesList.isEmpty) {
            return _buildEmptyState();
          }

          final allCategories = _extractCategories(spacesList);

          final filteredSpaces =
              selectedCategory == null
                  ? spacesList
                  : spacesList
                      .where((space) => space.category == selectedCategory)
                      .toList();

          return RefreshIndicator.adaptive(
            onRefresh: () => ref.refresh(listSpacesProvider.future),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildCategoryFilter(
                    ref,
                    allCategories,
                    selectedCategory,
                  ),
                ),
                if (filteredSpaces.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildNoResultsMessage(selectedCategory ?? 'All'),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: filteredSpaces.length,
                      itemBuilder:
                          (_, index) => SpaceCard(space: filteredSpaces[index]),
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                    ),
                  ),
              ],
            ),
          );
        },
        error: (_, __) => const Text('Oops, something unexpected happened'),
        loading: () => const LoadingIndicator(),
      ),
    );
  }

  List<String> _extractCategories(List<SpaceDetailSchema> spaces) {
    final categories =
        spaces
            .map((space) => space.category)
            .where((category) => category != null)
            .cast<String>()
            .toSet()
            .toList()
          ..sort();

    return categories;
  }

  Widget _buildCategoryFilter(
    WidgetRef ref,
    List<String> categories,
    String? selectedCategory,
  ) {
    return Builder(
      builder: (context) {
        return Container(
          height: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(
                  label: 'All',
                  isSelected: selectedCategory == null,
                  onTap: () {
                    ref.read(selectedCategoryProvider.notifier).state = null;
                  },
                ),
                ...categories.map(
                  (category) => _buildFilterChip(
                    label: category,
                    isSelected: category == selectedCategory,
                    onTap: () {
                      ref.read(selectedCategoryProvider.notifier).state =
                          category == selectedCategory ? null : category;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.only(right: 8),
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
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoResultsMessage(String category) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No spaces in "$category"',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try selecting a different category',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.explore, size: 80),
          SizedBox(height: 16),
          Text('No spaces available yet'),
        ],
      ),
    );
  }
}
