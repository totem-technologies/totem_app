import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/features/home/models/upcoming_session_data.dart';
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
import 'package:totem_app/features/home/screens/home_loading_screen.dart';
import 'package:totem_app/features/home/widgets/next_session_card.dart';
import 'package:totem_app/features/home/widgets/upcoming_session_card.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/utils.dart';
import 'package:totem_app/shared/widgets/empty_indicator.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(spacesSummaryProvider);
    ref.sentryReportFullyDisplayed(spacesSummaryProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: summary.when(
          data: (summary) {
            // Get the first non-ended upcoming event (user's next session)
            final nextSession = summary.upcoming
                .where((event) => !event.ended)
                .firstOrNull;

            if (summary.explore.isEmpty && nextSession == null) {
              return EmptyIndicator(
                icon: TotemIcons.home,
                onRetry: () => ref.refresh(spacesSummaryProvider.future),
              );
            }

            return RefreshIndicator.adaptive(
              onRefresh: () => ref.refresh(spacesSummaryProvider.future),
              child: CustomScrollView(
                slivers: [
                  // Your next session - shows only one session if user has one
                  if (nextSession != null) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 16,
                          end: 16,
                          top: 16,
                          bottom: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                'Your Next session',
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
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 16,
                        ),
                        child: NextSessionCard(session: nextSession),
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
