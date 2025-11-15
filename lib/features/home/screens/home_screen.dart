import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
import 'package:totem_app/features/spaces/widgets/space_card.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/empty_indicator.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/totem_icon.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _pageController = PageController(viewportFraction: 0.9);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = ref.watch(spacesSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const TotemLogo(size: 24)),
      body: SafeArea(
        bottom: false,
        child: summary.when(
          data: (summary) {
            final upcomingEvents = summary.upcoming
                .where((event) => !event.ended)
                .toList();

            if (summary.forYou.isEmpty &&
                summary.explore.isEmpty &&
                upcomingEvents.isEmpty) {
              return EmptyIndicator(
                icon: TotemIcons.home,
                onRetry: () => ref.refresh(spacesSummaryProvider.future),
              );
            }

            return RefreshIndicator.adaptive(
              onRefresh: () => ref.refresh(spacesSummaryProvider.future),
              child: CustomScrollView(
                slivers: [
                  if (upcomingEvents.isNotEmpty)
                    if (upcomingEvents.length == 1)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 16,
                          ),
                          child: SpaceCard.fromEventDetailSchema(
                            upcomingEvents.first,
                          ),
                        ),
                      )
                    else
                      SliverToBoxAdapter(
                        child: AspectRatio(
                          aspectRatio: 1.38,
                          child: PageView.builder(
                            padEnds: false,
                            controller: _pageController,
                            itemCount: upcomingEvents.length,
                            itemBuilder: (context, index) {
                              final event = upcomingEvents[index];
                              return Padding(
                                padding: EdgeInsetsDirectional.only(
                                  start: index == 0 ? 16 : 16,
                                  end: index == upcomingEvents.length - 1
                                      ? 16
                                      : 0,
                                ),
                                child: SpaceCard.fromEventDetailSchema(event),
                              );
                            },
                          ),
                        ),
                      ),
                  if (summary.forYou.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(16),
                        child: Text(
                          'Spaces for you',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
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
                            return SpaceCard(space: space, compact: true);
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
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    SliverSafeArea(
                      top: false,
                      sliver: SliverPadding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 16,
                          end: 16,
                          bottom: 16,
                        ),
                        sliver: SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: () {
                                  final screenWidth = MediaQuery.sizeOf(
                                    context,
                                  ).width;
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
                            return SpaceCard(space: space, compact: true);
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          loading: LoadingScreen.new,
          error: (error, stackTrace) {
            return ErrorScreen(
              error: error,
              showHomeButton: false,
              onRetry: () => ref.refresh(spacesSummaryProvider.future),
            );
          },
        ),
      ),
    );
  }
}
