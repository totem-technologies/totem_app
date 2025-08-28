import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/features/spaces/widgets/space_card.dart';

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
        if (spaces.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Padding(
              padding: horizontalPadding,
              child: Text(
                title ?? 'Upcoming Spaces',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              height: 210,
              child: ListView.separated(
                padding: horizontalPadding,
                scrollDirection: Axis.horizontal,
                itemCount: spaces.length,
                itemBuilder: (context, index) {
                  final space = spaces[index];
                  return SizedBox(
                    width: 160,
                    child: SmallSpaceCard(space: space),
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(width: 8),
              ),
            ),
          ],
        );
      },
      error: (error, _) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
    );
  }
}
