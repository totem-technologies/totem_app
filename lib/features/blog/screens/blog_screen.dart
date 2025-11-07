import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/blog/repositories/blog_repository.dart';
import 'package:totem_app/features/keeper/screens/meet_user_card.dart';
import 'package:totem_app/features/spaces/widgets/keeper_spaces.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/routing.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

class BlogScreen extends ConsumerStatefulWidget {
  const BlogScreen({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends ConsumerState<BlogScreen> {
  @override
  Widget build(BuildContext context) {
    final blogRef = ref.watch(blogPostProvider(widget.slug));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xffFCEFE4),
      body: SafeArea(
        child: blogRef.when(
          data: (blog) {
            final authorSpacesText =
                'Spaces by ${blog.author?.name ?? 'this Author'}';

            return NestedScrollView(
              headerSliverBuilder: (context, scrolled) {
                return [
                  SliverAppBar(
                    pinned: true,
                    elevation: 0,
                    automaticallyImplyLeading: false,
                    backgroundColor: const Color(0xffFCEFE4),
                    leading: Container(
                      height: 36,
                      width: 36,
                      margin: const EdgeInsetsDirectional.only(start: 20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: AlignmentDirectional.center,
                      child: Semantics(
                        label: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        button: true,
                        child: IconButton(
                          padding: const EdgeInsetsDirectional.only(start: 5),
                          alignment: AlignmentDirectional.center,
                          icon: Icon(Icons.adaptive.arrow_back, size: 20),
                          iconSize: 20,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => popOrHome(context),
                        ),
                      ),
                    ),
                    actionsPadding: const EdgeInsetsDirectional.only(end: 20),
                    actions: [
                      Container(
                        height: 36,
                        width: 36,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: AlignmentDirectional.center,
                        child: Semantics(
                          label: 'Share blog post',
                          button: true,
                          child: IconButton(
                            alignment: AlignmentDirectional.center,
                            padding: EdgeInsetsDirectional.zero,
                            icon: Icon(Icons.adaptive.share),
                            iconSize: 20,
                            visualDensity: VisualDensity.compact,
                            onPressed: () async {
                              final box =
                                  context.findRenderObject() as RenderBox?;
                              await SharePlus.instance.share(
                                ShareParams(
                                  uri: Uri.parse(AppConfig.mobileApiUrl)
                                      .resolve('/blog/${blog.slug}')
                                      .resolve(
                                        '?utm_source=app&utm_medium=share',
                                      ),
                                  sharePositionOrigin: box != null
                                      ? box.localToGlobal(Offset.zero) &
                                            box.size
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ];
              },
              body: SafeArea(
                top: false,
                child: RefreshIndicator.adaptive(
                  onRefresh: () =>
                      ref.refresh(blogPostProvider(widget.slug).future),
                  child: ListView(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 20,
                    ),
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        blog.title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: Colors.white,
                            child: UserAvatar.fromUserSchema(
                              blog.author,
                              radius: 15,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  blog.author?.name ?? 'Unknown Author',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (blog.datePublished != null)
                                  Text(
                                    DateFormat(
                                      'MMM d, yyyy',
                                    ).format(blog.datePublished!),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text('${blog.readTime} min read'),
                            backgroundColor: Colors.grey.shade200,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (blog.headerImageUrl != null)
                        Semantics(
                          label: 'Blog post header image',
                          image: true,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                              imageUrl: blog.headerImageUrl!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      Html(
                        data: blog.contentHtml,
                        onLinkTap: (url, _, _) async {
                          if (url != null) {
                            final appRoute = RoutingUtils.parseTotemDeepLink(
                              url,
                            );
                            if (appRoute != null && mounted) {
                              // Navigate to app route instead of browser
                              await context.push(appRoute);
                            } else {
                              // Open external URL for non-Totem links
                              await launchUrl(Uri.parse(url));
                            }
                          }
                        },
                        onAnchorTap: (url, _, _) async {
                          if (url != null) {
                            final appRoute = RoutingUtils.parseTotemDeepLink(
                              url,
                            );
                            if (appRoute != null && mounted) {
                              // Navigate to app route instead of browser
                              await context.push(appRoute);
                            } else {
                              // Open external URL for non-Totem links
                              await launchUrl(Uri.parse(url));
                            }
                          }
                        },
                        style: AppTheme.htmlStyle,
                      ),
                      if (blog.author?.slug != null) ...[
                        Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            vertical: 20,
                          ),
                          child: Text(
                            'Meet the author',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        MeetUserCard(
                          user: blog.author!,
                          margin: EdgeInsetsDirectional.zero,
                        ),
                        const SizedBox(height: 20),
                        KeeperSpaces(
                          title: authorSpacesText,
                          keeperSlug: blog.author!.slug!,
                          horizontalPadding: EdgeInsetsDirectional.zero,
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
          error: (error, _) => ErrorScreen(
            error: error,
            showHomeButton: true,
          ),
          loading: () => const LoadingIndicator(),
        ),
      ),
    );
  }
}
