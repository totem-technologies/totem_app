import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/models/space_schema.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';

class SubscribedSpacesScreen extends ConsumerWidget {
  const SubscribedSpacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final data = ref.watch(listSubscribedSpacesProvider);

    return Scaffold(
      appBar: AppBar(),
      body: data.when(
        data: (spaces) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: spaces.isEmpty
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Text(
                  'Subscribed Spaces',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                Text(
                  spaces.isEmpty
                      ? 'You are not subscribed to any Spaces.'
                      : 'These are the Spaces you will get notifications for '
                            'when new sessions are coming up.',
                  textAlign: TextAlign.center,
                ),
                if (spaces.isEmpty)
                  ElevatedButton(
                    onPressed: () {
                      toHome(HomeRoutes.spaces);
                    },
                    child: const Text('Browse Spaces'),
                  )
                else
                  for (final space in spaces)
                    if (space.slug != null)
                      _SubscribedSpaceTile(
                        key: ValueKey(space.slug!),
                        space: space,
                      ),
              ],
            ),
          );
        },
        error: (error, _) => ErrorScreen(error: error),
        loading: LoadingScreen.new,
      ),
    );
  }
}

class _SubscribedSpaceTile extends ConsumerStatefulWidget {
  const _SubscribedSpaceTile({required this.space, super.key});

  final SpaceSchema space;

  @override
  ConsumerState<_SubscribedSpaceTile> createState() =>
      _SubscribedSpaceTileState();
}

class _SubscribedSpaceTileState extends ConsumerState<_SubscribedSpaceTile> {
  var _loading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(35),
      ),
      padding: const EdgeInsetsDirectional.only(
        top: 10,
        start: 20,
        bottom: 10,
        end: 15,
      ),
      child: Row(
        children: [
          Expanded(child: Text(widget.space.title)),
          GestureDetector(
            onTap: () async {
              if (_loading || widget.space.slug == null) return;

              setState(() {
                _loading = true;
              });

              try {
                await ref.read(
                  unsubscribeFromSpaceProvider(widget.space.slug!).future,
                );
              } catch (error) {
                // This is handled internally
                // ignore: use_build_context_synchronously
                await ErrorHandler.handleApiError(context, error);
              } finally {
                if (mounted) {
                  setState(() {
                    _loading = false;
                  });
                }
              }
            },
            child: Container(
              height: 35,
              width: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: _loading
                    ? LoadingIndicator(
                        size: IconTheme.of(context).size ?? 24.0,
                      )
                    : const TotemIcon(
                        TotemIcons.delete,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
