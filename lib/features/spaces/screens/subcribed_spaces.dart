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
      body: SafeArea(
        child: data.when(
          data: (spaces) {
            if (spaces.isEmpty) {
              return Padding(
                padding: const EdgeInsetsDirectional.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    Text(
                      'Subscribed Spaces',
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const Text(
                      'You are not subscribed to any Spaces.',
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
            return NestedScrollView(
              headerSliverBuilder: (context, _) {
                return [
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 150,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        'Subscribed Spaces',
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      centerTitle: true,
                    ),
                  ),
                ];
              },
              body: RefreshIndicator.adaptive(
                onRefresh: () =>
                    ref.refresh(listSubscribedSpacesProvider.future),
                child: CustomScrollView(
                  slivers: <Widget>[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsetsDirectional.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Text(
                          'These are the Spaces you will get notifications for '
                          'when new sessions are coming up.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 20,
                        end: 20,
                        bottom: 20,
                      ),
                      sliver: SliverList.separated(
                        itemBuilder: (BuildContext context, int index) {
                          final space = spaces[index];
                          return _SubscribedSpaceTile(
                            key: ValueKey(space.slug!),
                            space: space,
                          );
                        },
                        itemCount: spaces.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                      ),
                    ),
                  ],
                ),
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
