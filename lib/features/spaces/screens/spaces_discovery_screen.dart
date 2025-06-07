import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/models/space_detail_schema.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/features/spaces/widgets/filter.dart';
import 'package:totem_app/features/spaces/widgets/space_card.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
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

    final isLargeScreen = MediaQuery.sizeOf(context).width > 600;

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
                  child: SpacesFilterBar(
                    categories: allCategories,
                    selectedCategory: selectedCategory,
                    onCategorySelected: (category) {
                      ref.read(selectedCategoryProvider.notifier).state =
                          category == selectedCategory ? null : category;
                    },
                  ),
                ),
                if (filteredSpaces.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildNoResultsMessage(selectedCategory ?? 'All'),
                  )
                else ...[
                  if (!isLargeScreen)
                    SliverPadding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 16,
                      ),
                      sliver: SliverList.separated(
                        itemCount: filteredSpaces.length,
                        itemBuilder:
                            (_, index) =>
                                SpaceCard(space: filteredSpaces[index]),
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 100,
                      ),
                      sliver: SliverGrid.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 16 / 14,
                        children:
                            filteredSpaces
                                .map((space) => SpaceCard(space: space))
                                .toList(),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
        error: (err, stack) => ErrorScreen(error: err),
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
