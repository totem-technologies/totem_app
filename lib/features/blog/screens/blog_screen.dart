import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/blog/repositories/blog_repository.dart';
import 'package:totem_app/features/keeper/screens/meet_user_card.dart';
import 'package:totem_app/features/spaces/widgets/keeper_spaces.dart';
import 'package:totem_app/navigation/app_router.dart';
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
      body: blogRef.when(
        data: (blog) {
          return RefreshIndicator.adaptive(
            onRefresh: () => ref.refresh(blogPostProvider(widget.slug).future),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  leading: Container(
                    height: 36,
                    width: 36,
                    margin: const EdgeInsetsDirectional.only(start: 20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: const EdgeInsets.only(left: 5),
                      alignment: Alignment.center,
                      icon: Icon(Icons.adaptive.arrow_back, size: 20),
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => popOrHome(context),
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
                      child: IconButton(
                        alignment: Alignment.center,
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.adaptive.share),
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          final box = context.findRenderObject() as RenderBox?;
                          SharePlus.instance.share(
                            ShareParams(
                              uri: Uri.parse(
                                '${AppConfig.mobileApiUrl}'
                                'blog/${blog.slug}'
                                '?utm_source=app&utm_medium=share',
                              ),
                              sharePositionOrigin: box != null
                                  ? box.localToGlobal(Offset.zero) & box.size
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                SliverSafeArea(
                  top: false, // AppBar handles top safe area
                  sliver: SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.list(
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
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                              imageUrl: blog.headerImageUrl!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        Html(
                          data: blog.contentHtml,
                          onLinkTap: (url, _, _) {
                            if (url != null) launchUrl(Uri.parse(url));
                          },
                          onAnchorTap: (url, _, _) {
                            if (url != null) launchUrl(Uri.parse(url));
                          },
                          style: AppTheme.htmlStyle,
                        ),
                        if (blog.author?.slug != null) ...[
                          Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 16,
                              vertical: 20,
                            ),
                            child: Text(
                              'Meet the author',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          MeetUserCard(user: blog.author!),
                          const SizedBox(height: 20),
                          KeeperSpaces(
                            title:
                                'Spaces by ${blog.author?.name ?? 'this Author'}',
                            keeperSlug: blog.author!.slug!,
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        error: (error, _) => ErrorScreen(
          error: error,
          showHomeButton: true,
        ),
        loading: () {
          return const LoadingIndicator();
        },
      ),
    );
  }
}
