import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/models/next_event_schema.dart';
import 'package:totem_app/api/models/space_detail_schema.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/features/spaces/widgets/space_card.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';

class SessionHistoryScreen extends ConsumerWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final asyncValue = ref.watch(listSessionsHistoryProvider);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: asyncValue.when(
          data: (data) {
            if (data.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    Text(
                      'Session History',
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const Text(
                      'You have not joined any Spaces yet.',
                      textAlign: TextAlign.center,
                    ),
                    ElevatedButton(
                      onPressed: () {
                        toHome(HomeRoutes.spaces);
                      },
                      child: const Text('Browse Spaces'),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator.adaptive(
              onRefresh: () => ref.refresh(listSessionsHistoryProvider.future),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Session History',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Here are the recent sessions you have been a part of.',
                    textAlign: TextAlign.center,
                  ),

                  for (final session in data)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 20),
                      child: SpaceCard(
                        space: SpaceDetailSchema(
                          slug: session.space.slug!,
                          author: session.space.author,
                          category: '',
                          imageLink: session.space.image,
                          nextEvent: NextEventSchema(
                            link: session.calLink,
                            seatsLeft: session.seatsLeft,
                            start: session.start.toIso8601String(),
                            title: session.title,
                            slug: session.slug,
                          ),
                          description: session.space.subtitle,
                          title: session.space.title,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
          error: (error, _) => ErrorScreen(error: error),
          loading: LoadingScreen.new,
        ),
      ),
    );
  }
}
