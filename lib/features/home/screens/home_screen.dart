import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/home/models/upcoming_session_data.dart';
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
import 'package:totem_app/features/home/screens/home_loading_screen.dart';
import 'package:totem_app/api/models/blog_post_list_schema.dart';
import 'package:totem_app/features/blog/repositories/blog_repository.dart';
import 'package:totem_app/features/home/widgets/home_blog_card.dart';
import 'package:totem_app/features/home/widgets/next_session_card.dart';
import 'package:totem_app/features/home/widgets/upcoming_session_card.dart';
import 'package:totem_app/features/home/widgets/welcome_card.dart';
import 'package:totem_app/features/spaces/screens/spaces_discovery_screen.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/utils.dart';
import 'package:totem_app/shared/widgets/empty_indicator.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';

/// Builds slivers for the Blogs section when blog posts are available.
List<Widget> _blogSectionSlivers(WidgetRef ref, ThemeData theme) {
  final blogAsync = ref.watch(listBlogPostsProvider);
  final items = blogAsync.maybeWhen(
    data: (page) => page.items,
    orElse: () => <BlogPostListSchema>[],
  );
  if (items.isEmpty) return const [];

  return [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: 20,
          end: 20,
          top: 24,
          bottom: 16,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Blogs',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
            const _ViewAllButton(destination: HomeRoutes.blog),
          ],
        ),
      ),
    ),
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        child: HomeBlogCard(data: items.first),
      ),
    ),
    const SliverToBoxAdapter(child: SizedBox(height: 16)),
  ];
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(spacesSummaryProvider);
    ref.sentryReportFullyDisplayed(spacesSummaryProvider);

    // Get the user's circle count to determine if they're a new user
    final circleCount = ref.watch(
      authControllerProvider.select((auth) => auth.user?.circleCount ?? 0),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: summary.when(
          data: (summary) {
            final nextSession = summary.upcoming
                .where((event) => !event.ended)
                .firstOrNull;
            final isNewUser = circleCount == 0 && nextSession == null;

            if (summary.explore.isEmpty && nextSession == null && !isNewUser) {
              return EmptyIndicator(
                icon: TotemIcons.home,
                onRetry: () => ref.refresh(spacesSummaryProvider.future),
              );
            }

            return RefreshIndicator.adaptive(
              onRefresh: () => ref.refresh(spacesSummaryProvider.future),
              child: CustomScrollView(
                slivers: [
                  if (isNewUser) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: 16,
                          end: 16,
                          top: 16,
                          bottom: 16,
                        ),
                        child: WelcomeCard(),
                      ),
                    ),
                  ] else if (nextSession != null) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 20,
                          end: 20,
                          top: 16,
                          bottom: 16,
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
                            const _ViewAllButton(filterMySessions: true),
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
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 16),
                    ),
                  ],
                  if (summary.explore.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 20,
                          end: 20,
                          top: 8,
                          bottom: 16,
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
                            const _ViewAllButton(),
                          ],
                        ),
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final screenWidth = MediaQuery.sizeOf(context).width;
                        final isTablet = screenWidth >= 600;
                        final sessionLimit = isTablet ? 10 : 5;
                        final upcomingSessions =
                            UpcomingSessionData.fromSummary(
                              summary,
                              limit: sessionLimit,
                            );

                        if (isTablet) {
                          return SliverPadding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 16,
                              end: 16,
                              bottom: 16,
                            ),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 20,
                                    crossAxisSpacing: 16,
                                    mainAxisExtent: 140,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final sessionData = upcomingSessions[index];
                                  return UpcomingSessionCard(data: sessionData);
                                },
                                childCount: upcomingSessions.length,
                              ),
                            ),
                          );
                        }

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
                  // Blog section at bottom (Figma: "Blogs" header + single card + View All)
                  ..._blogSectionSlivers(ref, theme),
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

class _ViewAllButton extends ConsumerWidget {
  const _ViewAllButton({
    this.filterMySessions = false,
    this.destination,
  });

  /// When true, sets "My Sessions" filter before navigating to Spaces.
  final bool filterMySessions;

  /// When set, navigates to this tab instead of Spaces (e.g. HomeRoutes.blog).
  final HomeRoutes? destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final route = destination ?? HomeRoutes.spaces;

    return TextButton(
      onPressed: () {
        if (route == HomeRoutes.spaces && filterMySessions) {
          ref.read(mySessionsFilterProvider.notifier).setMySessionFilter(true);
        }
        toHome(route);
      },
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
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.gray,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppTheme.gray,
          ),
        ],
      ),
    );
  }
}
