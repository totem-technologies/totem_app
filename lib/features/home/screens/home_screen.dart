import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
import 'package:totem_app/features/spaces/widgets/space_card.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/totem_icon.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(spacesSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const TotemLogo(size: 24)),
      body: summary.when(
        data: (summary) {
          // If there is more than one upcoming event, we will show a horizontal
          // list of cards with the next card visible.
          final factor = summary.upcoming.length == 1 ? 1 : 3;
          final upcomingCardWidth =
              MediaQuery.sizeOf(context).width - 16 * factor;

          return RefreshIndicator.adaptive(
            onRefresh: () => ref.refresh(spacesSummaryProvider.future),
            child: CustomScrollView(
              slivers: [
                if (summary.upcoming.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 300,
                      child: CarouselView(
                        padding: const EdgeInsets.only(
                          left: 16,
                        ),
                        itemExtent: upcomingCardWidth.clamp(180, 350),
                        children: [
                          for (final event in summary.upcoming)
                            SpaceCard(
                              space: SpaceDetailSchema(
                                slug: event.space.slug!,
                                title: event.space.title,
                                imageLink: event.space.image,
                                description: event.space.subtitle,
                                author: event.space.author,
                                nextEvent: NextEventSchema(
                                  start: event.start.toIso8601String(),
                                  link: event.calLink,
                                  seatsLeft: event.seatsLeft,
                                  slug: event.slug,
                                  title: event.title,
                                ),
                                // category: event.space.categories:,
                                category: '',
                              ),
                            ),
                        ],
                      ),
                      // child: ListView.separated(
                      //   scrollDirection: Axis.horizontal,
                      //   itemCount: summary.upcoming.length,
                      //   padding: const EdgeInsetsDirectional.symmetric(
                      //     horizontal: 16,
                      //   ),
                      //   itemBuilder: (context, index) {
                      //     final event = summary.upcoming[index];

                      //     return SizedBox(
                      //       width: upcomingCardWidth.clamp(180, 350),
                      //       child: SpaceCard(
                      //         space: SpaceDetailSchema(
                      //           slug: event.space.slug!,
                      //           title: event.space.title,
                      //           imageLink: event.space.image,
                      //           description: event.space.subtitle,
                      //           author: event.space.author,
                      //           nextEvent: NextEventSchema(
                      //             start: event.start.toIso8601String(),
                      //             link: event.calLink,
                      //             seatsLeft: event.seatsLeft,
                      //             slug: event.slug,
                      //             title: event.title,
                      //           ),
                      //           // category: event.space.categories:,
                      //           category: '',
                      //         ),
                      //       ),
                      //     );
                      //   },
                      //   separatorBuilder: (_, _) => const SizedBox(width: 16),
                      // ),
                    ),
                  ),

                if (summary.forYou.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(16),
                      child: Text(
                        'Spaces for you',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 180,
                      child: ListView.separated(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 16,
                        ),
                        scrollDirection: Axis.horizontal,
                        itemCount: summary.forYou.length,
                        itemBuilder: (context, index) {
                          final space = summary.forYou[index];
                          return SpaceCard(space: space);
                        },
                        separatorBuilder: (_, _) => const SizedBox(width: 16),
                      ),
                    ),
                  ),
                ],
                if (summary.explore.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(16),
                      child: Text(
                        'Explore spaces',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 16,
                      end: 16,
                      bottom: 16,
                    ),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: () {
                          final screenWidth = MediaQuery.sizeOf(context).width;
                          if (screenWidth < 600) {
                            return 2; // Small screens
                          } else if (screenWidth < 900) {
                            return 3; // Medium screens
                          }
                          return 4; // Large screens
                        }(),
                        childAspectRatio: 16 / 21,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: summary.explore.length,
                      itemBuilder: (context, index) {
                        final space = summary.explore[index];
                        return SpaceCard(space: space);
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: LoadingScreen.new,
        error: (error, stackTrace) {
          return ErrorScreen(error: error);
        },
      ),
    );
  }
}
