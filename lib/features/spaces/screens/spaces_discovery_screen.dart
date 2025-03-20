import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:totem_app/api/models/space_detail_schema.dart';
import 'package:totem_app/core/config/app_config.dart';

import '../repositories/space_repository.dart';

// Provider to track the selected category filter
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

class SpacesDiscoveryScreen extends ConsumerWidget {
  const SpacesDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var spaces = ref.watch(listSpacesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Spaces'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              context.push('/profile');
            },
          ),
        ],
      ),
      body: Center(
        child: spaces.when(
          data: (spacesList) {
            if (spacesList.isEmpty) {
              return _buildEmptyState();
            }

            // Extract unique categories from spaces
            final allCategories = _extractCategories(spacesList);

            // Filter spaces by selected category
            final filteredSpaces =
                selectedCategory == null
                    ? spacesList
                    : spacesList
                        .where((space) => space.category == selectedCategory)
                        .toList();

            return Column(
              children: [
                // Category filter
                _buildCategoryFilter(
                  context,
                  ref,
                  allCategories,
                  selectedCategory,
                ),

                // Spaces list
                Expanded(
                  child:
                      filteredSpaces.isEmpty
                          ? _buildNoResultsMessage(selectedCategory!)
                          : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: filteredSpaces.length,
                            itemBuilder:
                                (context, index) => _buildSpaceCard(
                                  context,
                                  filteredSpaces[index],
                                ),
                          ),
                ),
              ],
            );
          },
          error: (_, __) => const Text('Oops, something unexpected happened'),
          loading: () => const CircularProgressIndicator(),
        ),
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
            .toList();

    // Sort categories alphabetically
    categories.sort();
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
          // "All" filter option
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap:
                  () =>
                      ref.read(selectedCategoryProvider.notifier).state = null,
              borderRadius: BorderRadius.circular(16),
              child: Chip(
                label: const Text('All'),
                avatar: const Icon(Icons.apps, size: 16),
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.explore, size: 80),
        const SizedBox(height: 16),
        const Text('Spaces Discovery Screen', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 32),
        const Text('No spaces available yet'),
      ],
    );
  }

  String _formatEventDateTime(String isoUtcString) {
    try {
      final dateTime = DateTime.parse(isoUtcString);
      final dateFormat = DateFormat.yMMMd(); // e.g., Apr 27, 2023
      final timeFormat = DateFormat.jm(); // e.g., 2:30 PM
      return '${dateFormat.format(dateTime)} at ${timeFormat.format(dateTime)}';
    } catch (e) {
      return 'Date TBA';
    }
  }

  Widget _buildSpaceCard(BuildContext context, SpaceDetailSchema space) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Space image if available
          if (space.imageLink != null)
            CachedNetworkImage(
              imageUrl: getFullUrl(space.imageLink!),
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget:
                  (context, error, stackTrace) => Container(
                    height: 120,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.image_not_supported, size: 40),
                    ),
                  ),
            ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and category
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        space.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (space.category != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Chip(
                          label: Text(
                            space.category!,
                            style: const TextStyle(fontSize: 12),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // Description (truncated)
                Text(
                  space.description.length > 100
                      ? '${space.description.substring(0, 100)}...'
                      : space.description,
                  style: TextStyle(color: Colors.grey[700]),
                ),

                const SizedBox(height: 12),

                // Author info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundImage:
                          space.author.profileImage != null
                              ? CachedNetworkImageProvider(
                                getFullUrl(space.author.profileImage!),
                              )
                              : null,
                      child:
                          space.author.profileImage == null
                              ? Text(space.author.name?[0].toUpperCase() ?? "")
                              : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Created by ${space.author.name}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Next event info if available
                if (space.nextEvent.link.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.event,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Next: ${space.nextEvent.title ?? "Upcoming Event"}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (space.nextEvent.start.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 4.0,
                              left: 24.0,
                            ),
                            child: Text(
                              _formatEventDateTime(space.nextEvent.start),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Action button
          InkWell(
            onTap: () {
              context.push('/spaces/${space.nextEvent.slug}');
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                border: Border(
                  top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
              ),
              child: const Center(
                child: Text(
                  'View Space',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
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
