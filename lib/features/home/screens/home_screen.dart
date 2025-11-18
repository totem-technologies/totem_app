import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
import 'package:totem_app/features/home/screens/home_loading_screen.dart';
import 'package:totem_app/features/spaces/widgets/space_card.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/empty_indicator.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/totem_icon.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
                  SliverSafeArea(
                    sliver: SliverPadding(
                      padding: const EdgeInsetsDirectional.only(
                        bottom: 16,
                      ),
                      sliver: SliverList.list(
                        children: [
                          if (upcomingEvents.isNotEmpty)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 16,
                                end: 16,
                                bottom: 16,
                              ),
                              child: Text(
                                'Your upcoming sessions',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          if (upcomingEvents.length == 1)
                            Container(
                              constraints: BoxConstraints(
                                maxHeight: clampDouble(
                                  MediaQuery.heightOf(context) * 0.3,
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
                            )
                          else
                            SizedBox(
                              height: clampDouble(
                                MediaQuery.heightOf(context) * 0.3,
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
                                        MediaQuery.widthOf(context) * 0.8,
                                        200,
                                        400,
                                      ),
                                    ),
                                    child: SpaceCard.fromEventDetailSchema(
                                      event,
                                    ),
                                  );
                                },
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 16),
                              ),
                            ),
                          if (summary.forYou.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsetsDirectional.all(16),
                              child: Text(
                                'Spaces for you',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            SizedBox(
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
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 16),
                              ),
                            ),
                          ],
                          if (summary.explore.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsetsDirectional.all(16),
                              child: Text(
                                'Explore spaces',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 16,
                                end: 16,
                              ),
                              child: SliverGrid.builder(
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
                          ],
                        ],
                      ),
                    ),
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
