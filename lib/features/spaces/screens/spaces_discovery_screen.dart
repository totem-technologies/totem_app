import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:totem_app/api/models/mobile_space_detail_schema.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/features/spaces/widgets/filter.dart';
import 'package:totem_app/features/spaces/widgets/space_card.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/utils.dart';
import 'package:totem_app/shared/widgets/empty_indicator.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/totem_icon.dart';

// Provider to track the selected category filter
class SelectedCategoryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void toggleCategory(String? category) {
    state = (state == category) ? null : category;
  }
}

// Provider
final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryNotifier, String?>(
      SelectedCategoryNotifier.new,
      name: 'Selected Category Provider',
    );

class SpacesDiscoveryScreen extends ConsumerWidget {
  const SpacesDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaces = ref.watch(listSpacesProvider);
    ref.sentryReportFullyDisplayed(listSpacesProvider);

    final selectedCategory = ref.watch(selectedCategoryProvider);

    final isLargeScreen = MediaQuery.widthOf(context) > 600;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 72,
        titleSpacing: 0,
        centerTitle: true,
        title: spaces.maybeWhen(
          data: (spacesList) {
            if (spacesList.isEmpty) return const TotemLogo(size: 24);
            return SpacesFilterBar(
              categories: _extractCategories(spacesList),
              selectedCategory: selectedCategory,
              onCategorySelected: (category) {
                ref
                    .read(selectedCategoryProvider.notifier)
                    .toggleCategory(category);
              },
            );
          },
          orElse: () => const TotemLogo(size: 24),
        ),
      ),
      body: spaces.when(
        data: (spacesList) {
          if (spacesList.isEmpty) {
            return EmptyIndicator(
              icon: TotemIcons.spacesFilled,
              text: 'No spaces available yet.',
              onRetry: () => ref.refresh(listSpacesProvider.future),
            );
          }

          final filteredSpaces = selectedCategory == null
              ? spacesList
              : spacesList
                    .where((space) => space.category == selectedCategory)
                    .toList();

          return RefreshIndicator.adaptive(
            edgeOffset: 80,
            onRefresh: () => ref.refresh(listSpacesProvider.future),
            child: CustomScrollView(
              slivers: [
                SliverSafeArea(
                  top: false,
                  sliver: MultiSliver(
                    children: <Widget>[
                      SliverPadding(
                        padding: EdgeInsets.only(
                          top: MediaQuery.paddingOf(context).top + 80,
                        ),
                      ),
                      if (filteredSpaces.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildNoResultsMessage(
                            selectedCategory ?? 'All',
                          ),
                        )
                      else ...[
                        if (!isLargeScreen)
                          SliverPadding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 16,
                              end: 16,
                              bottom: 20,
                            ),
                            sliver: SliverList.separated(
                              itemCount: filteredSpaces.length,
                              itemBuilder: (_, index) =>
                                  SpaceCard(space: filteredSpaces[index]),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 16),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 100,
                            ),
                            sliver: SliverGrid.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: 16 / 14,
                                  ),
                              itemCount: filteredSpaces.length,
                              itemBuilder: (_, index) =>
                                  SpaceCard(space: filteredSpaces[index]),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        error: (err, stack) => Padding(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 72),
          child: ErrorScreen(
            error: err,
            showHomeButton: false,
            onRetry: () => ref.refresh(listSpacesProvider.future),
          ),
        ),
        loading: () {
          return ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsetsDirectional.only(
              start: 16,
              end: 16,
              bottom: 16,
              top: MediaQuery.paddingOf(context).top + 80,
            ),
            itemBuilder: (_, _) => SpaceCard.shimmer(),
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemCount: (MediaQuery.heightOf(context) / 100).round(),
          );
        },
      ),
    );
  }

  List<String> _extractCategories(List<MobileSpaceDetailSchema> spaces) {
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
}
