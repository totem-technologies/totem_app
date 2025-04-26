import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/models/space_detail_schema.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/features/spaces/widgets/space_card.dart';
import 'package:totem_app/shared/widgets/totem_icon.dart';

import '../repositories/space_repository.dart';

// Provider to track the selected category filter
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

class SpacesDiscoveryScreen extends ConsumerWidget {
  const SpacesDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaces = ref.watch(listSpacesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return Scaffold(
      appBar: AppBar(leading: const TotemIcon()),
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

          return Column(
            children: [
              _buildCategoryFilter(
                context,
                ref,
                allCategories,
                selectedCategory,
              ),

              Expanded(
                child:
                    filteredSpaces.isEmpty
                        ? _buildNoResultsMessage(selectedCategory!)
                        : ListView.separated(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: filteredSpaces.length,
                          itemBuilder:
                              (_, index) =>
                                  SpaceCard(space: filteredSpaces[index]),
                          separatorBuilder:
                              (_, _) => const SizedBox(height: 16),
                        ),
              ),
            ],
          );
        },
        error: (_, __) => const Text('Oops, something unexpected happened'),
        loading: () => const CircularProgressIndicator(),
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
    BuildContext context,
    WidgetRef ref,
    List<String> categories,
    String? selectedCategory,
  ) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap:
                  () =>
                      ref.read(selectedCategoryProvider.notifier).state = null,
              borderRadius: BorderRadius.circular(16),
              child: Chip(
                label: const Text('All'),
                backgroundColor:
                    selectedCategory == null
                        ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.1),
                labelStyle: TextStyle(
                  color:
                      selectedCategory == null
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black87,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
          ...categories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: () {
                  ref.read(selectedCategoryProvider.notifier).state =
                      category == selectedCategory ? null : category;
                },
                borderRadius: BorderRadius.circular(16),
                child: Chip(
                  label: Text(category),
                  backgroundColor:
                      category == selectedCategory
                          ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color:
                        category == selectedCategory
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black87,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ),
        ],
      ),
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

String getFullUrl(String url) {
  if (url.isEmpty) {
    return '';
  }

  // Check if URL is already fully qualified
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }

  // Ensure the URL and base path are properly joined
  final baseUrl = AppConfig.apiUrl;
  // Remove trailing slash from base URL if any
  final normalizedBaseUrl =
      baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
  // Ensure url starts with a slash
  final normalizedUrl = url.startsWith('/') ? url : '/$url';

  return '$normalizedBaseUrl$normalizedUrl';
}
