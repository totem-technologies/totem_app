import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/features/home/models/upcoming_session_data.dart';
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
import 'package:totem_app/features/home/screens/home_loading_screen.dart';
import 'package:totem_app/features/home/widgets/upcoming_session_card.dart';
import 'package:totem_app/features/spaces/widgets/space_card.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/utils.dart';
import 'package:totem_app/shared/widgets/empty_indicator.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/totem_icon.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(spacesSummaryProvider);
    ref.sentryReportFullyDisplayed(spacesSummaryProvider);
    final mediaSize = MediaQuery.sizeOf(context);
    final screenWidth = mediaSize.width;
    final screenHeight = mediaSize.height;

    return Scaffold(
      appBar: AppBar(title: const TotemLogo(size: 24)),
      body: SafeArea(
        bottom: false,
        child: summary.when(
          data: (summary) {
            final upcomingEvents = [
              for (final event in summary.upcoming)
                if (!event.ended) event,
            ];

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
                  if (upcomingEvents.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 16,
                          end: 16,
                          bottom: 16,
                        ),
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Your upcoming sessions',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (upcomingEvents.length == 1)
                      SliverToBoxAdapter(
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight: clampDouble(
                              screenHeight * 0.3,
                              200,
                              300,
                            ),
                          ),
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
                        child: SizedBox(
                          height: clampDouble(
                            screenHeight * 0.3,
                            200,
                            300,
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 16,
                            ),
                            scrollDirection: Axis.horizontal,
                            itemCount: upcomingEvents.length,
                            itemBuilder: (context, index) {
                              final event = upcomingEvents[index];
                              return ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: clampDouble(
                                    screenWidth * 0.8,
                                    200,
                                    400,
                                  ),
                                ),
                                child: SpaceCard.fromEventDetailSchema(event),
                              );
                            },
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 16),
                          ),
                        ),
                      ),
                  ],
                  if (summary.forYou.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(16),
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Spaces for you',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
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
                  // Upcoming Sessions section - replacing Explore Spaces
                  // Gathers available sessions from explore spaces
                  if (summary.explore.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 16,
                          end: 16,
                          top: 8,
                          bottom: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                'Upcoming Sessions',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            // View All link switches to Spaces tab
                            TextButton(
                              onPressed: () => toHome(HomeRoutes.spaces),
                              style: TextButton.styleFrom(
                                padding: EdgeInsetsDirectional.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'View All',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Build list of upcoming sessions from explore spaces
                    Builder(
                      builder: (context) {
                        // Extract upcoming sessions from explore spaces
                        final upcomingSessions =
                            UpcomingSessionData.fromSummary(summary);

                        return SliverPadding(
                          padding: const EdgeInsetsDirectional.only(
                            start: 16,
                            end: 16,
                            bottom: 16,
                          ),
                          sliver: SliverList.separated(
                            itemCount: upcomingSessions.length,
                            itemBuilder: (context, index) {
                              final sessionData = upcomingSessions[index];
                              return UpcomingSessionCard(data: sessionData);
                            },
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 20),
                          ),
                        );
                      },
                    ),
                  ],
                  const SliverSafeArea(
                    top: false,
                    sliver: SliverToBoxAdapter(),
                  ),
                ],
              ),
            );
          },
          loading: () => const HomeLoadingScreen(),
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
