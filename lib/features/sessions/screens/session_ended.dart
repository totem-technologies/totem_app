import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/features/spaces/widgets/space_card.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/totem_icons.dart';

class SessionEndedScreen extends ConsumerWidget {
  const SessionEndedScreen({required this.event, super.key});

  final EventDetailSchema event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recommended = ref.watch(getRecommendedSesssionsProvider());
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 20,
                    children: [
                      TotemIcon(
                        TotemIcons.checkboxOutlined,
                        size: 100,
                        color: theme.textTheme.headlineMedium?.color,
                      ),
                      Text(
                        'Session Ended',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const Text(
                        'Thanks for joining. Hope you enjoyed the session!',
                        textAlign: TextAlign.center,
                      ),
                      ElevatedButton(
                        onPressed: () => toHome(HomeRoutes.initialRoute),
                        child: const Text('Go Back to Home'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.end,
                    spacing: 8,
                    children: [
                      Text(
                        'You may enjoy these spaces',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.start,
                      ),
                      ...recommended.when(
                        data: (data) sync* {
                          for (final event in data.take(2)) {
                            yield Flexible(
                              child: SpaceCard.fromEventDetailSchema(event),
                            );
                          }
                        },
                        error: (error, _) => [],
                        loading: () => [],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
