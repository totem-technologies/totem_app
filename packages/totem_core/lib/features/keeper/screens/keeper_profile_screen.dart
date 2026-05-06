import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/keeper/repositories/keeper_repository.dart';
import 'package:totem_app/features/spaces/widgets/keeper_spaces.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/html.dart';
import 'package:totem_app/shared/routing.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/utils.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/totem_icon.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';
import 'package:url_launcher/link.dart';

class KeeperProfileScreen extends ConsumerWidget {
  const KeeperProfileScreen({
    required this.slug,
    this.showAppBar = true,
    super.key,
  });

  final String slug;

  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(keeperProfileProvider(slug));
    ref.sentryReportFullyDisplayed(keeperProfileProvider(slug));
    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              leading: BackButton(
                onPressed: () => popOrHome(context),
              ),
              title: const TotemLogo(size: 24),
            )
          : null,
      body: async.when(
        data: (keeper) {
          final bottomSafeArea = MediaQuery.paddingOf(context).bottom;
          return SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsetsDirectional.only(
                top: 16,
                bottom: 16 + bottomSafeArea,
              ),
              children: [
                IntrinsicHeight(
                  child: Container(
                    margin: const EdgeInsetsDirectional.symmetric(
                      horizontal: 20,
                    ),
                    constraints: const BoxConstraints(
                      maxWidth: 400,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    padding: const EdgeInsetsDirectional.symmetric(
                      vertical: 20,
                      horizontal: 22,
                    ),
                    child: Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              UserAvatar.fromUserSchema(
                                keeper.user,
                                radius: 52,
                              ),
                              Text(
                                keeper.user.name ?? 'Keeper',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(keeper.location),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (keeper.website != null &&
                                      keeper.website!.isNotEmpty)
                                    Link(
                                      uri: Uri.parse(keeper.website!),
                                      builder: (context, followLink) {
                                        return IconButton(
                                          icon: const TotemIcon(
                                            TotemIcons.link,
                                            size: 20,
                                          ),
                                          onPressed: followLink,
                                          iconSize: 20,
                                        );
                                      },
                                    ),
                                  if (keeper.instagramUsername != null &&
                                      keeper.instagramUsername!.isNotEmpty)
                                    Link(
                                      uri: Uri.parse(
                                        'https://instagram.com/${keeper.instagramUsername!}',
                                      ),
                                      builder: (context, followLink) {
                                        return IconButton(
                                          icon: const TotemIcon(
                                            TotemIcons.instagram,
                                            size: 20,
                                          ),
                                          onPressed: followLink,
                                          iconSize: 20,
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Spacer(),
                              Text(
                                '${keeper.circleCount}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const Text('Hosted Spaces'),
                              const Spacer(),
                              Text(
                                keeper.languages,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const Text('Languages'),
                              const Spacer(),
                              Text(
                                keeper.monthJoined,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const Text('Month Joined'),
                              const Spacer(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 20,
                  ),
                  child: Text(
                    'Biography',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 20,
                  ),
                  child: Html(
                    data: keeper.bioHtml ?? keeper.bio,
                    style: AppTheme.compactHtmlStyle,
                    onLinkTap: (url, _, _) async {
                      RoutingUtils.handleLinkTap(context, url);
                    },
                    onAnchorTap: (url, _, _) async {
                      RoutingUtils.handleLinkTap(context, url);
                    },
                    extensions: [TotemImageHtmlExtension()],
                  ),
                ),
                const SizedBox(height: 20),
                KeeperSpaces(
                  keeperSlug: keeper.user.slug!,
                  horizontalPadding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 20,
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, stack) => ErrorScreen(
          error: error,
          onRetry: () => ref.refresh(keeperProfileProvider(slug).future),
          showHomeButton: false,
        ),
      ),
    );
  }
}
