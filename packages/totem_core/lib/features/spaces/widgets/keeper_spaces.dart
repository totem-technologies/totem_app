import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:totem_app/features/home/models/upcoming_session_data.dart';
import 'package:totem_app/features/home/widgets/upcoming_session_card.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';

class KeeperSpaces extends ConsumerWidget {
  const KeeperSpaces({
    required this.keeperSlug,
    this.title,
    this.horizontalPadding = const EdgeInsetsDirectional.symmetric(
      horizontal: 16,
    ),
    super.key,
  });

  final String keeperSlug;

  final String? title;
  final EdgeInsetsGeometry horizontalPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spaces = ref.watch(listSpacesByKeeperProvider(keeperSlug));

    return spaces.when(
      data: (spaces) {
        final sessions = [
          for (final space in spaces)
            if (space.nextEvents.isNotEmpty)
              UpcomingSessionData.fromSpaceAndSession(
                space,
                space.nextEvents.first,
              ),
        ];

        if (sessions.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Padding(
              padding: horizontalPadding,
              child: Text(
                title ?? 'Upcoming Sessions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...sessions.map(
              (data) => Padding(
                padding: horizontalPadding,
                child: UpcomingSessionCard(data: data),
              ),
            ),
          ],
        );
      },
      error: (error, _) => const SizedBox.shrink(),
      loading: () {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Padding(
              padding: horizontalPadding,
              child: Text(
                title ?? 'Upcoming Sessions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...List.generate(
              3,
              (_) => Padding(
                padding: horizontalPadding,
                child: Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    height: 131,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
