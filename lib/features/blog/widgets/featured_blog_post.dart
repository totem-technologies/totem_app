import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:totem_app/api/models/blog_post_list_schema.dart';
import 'package:totem_app/features/blog/widgets/badge.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

class FeaturedBlogPost extends StatelessWidget {
  const FeaturedBlogPost({
    required this.title,
    required this.subtitle,
    required this.authorName,
    required this.authorImageUrl,
    required this.authorImageSeed,
    required this.publishedDate,
    required this.image,
    required this.slug,
    required this.readTime,
    required this.isPublished,
    this.isLarge = false,
    super.key,
  });

  FeaturedBlogPost.fromBlogPostSchema(
    BlogPostListSchema schema, {
    this.isLarge = false,
    super.key,
  }) : title = schema.title,
       subtitle = schema.subtitle ?? '',
       authorName = schema.author?.name ?? 'Keeper',
       authorImageUrl = schema.author?.profileImage,
       authorImageSeed = schema.author?.profileAvatarSeed ?? '',
       publishedDate = schema.datePublished,
       slug = schema.slug!,
       image = schema.headerImageUrl,
       readTime = schema.readTime,
       isPublished = schema.publish;
  final String title;
  final String subtitle;
  final String authorName;
  final String? authorImageUrl;
  final String authorImageSeed;
  final DateTime? publishedDate;
  final String? image;
  final String slug;
  final bool isLarge;
  final int readTime;
  final bool isPublished;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.widthOf(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    return SizedBox(
      height: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ShaderMask(
                  shaderCallback: (rect) {
                    final cardHeight = rect.height;
                    const gradientHeight = 135.0;
                    final startStop =
                        ((cardHeight - gradientHeight) / cardHeight).clamp(
                          0.0,
                          1.0,
                        );
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: const [Colors.transparent, Colors.black],
                      stops: [startStop, 1.0],
                    ).createShader(
                      Rect.fromLTRB(0, 0, rect.width, rect.height),
                    );
                  },
                  blendMode: BlendMode.darken,
                  child: CachedNetworkImage(
                    imageUrl: image ?? '',
                    fit: BoxFit.cover,
                    memCacheWidth: (screenWidth * pixelRatio).round(),
                    memCacheHeight: (345 * pixelRatio).round(),
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) {
                      return Image.asset(
                        'assets/images/welcome_background.jpg',
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
                PositionedDirectional(
                  bottom: 20,
                  start: 20,
                  end: 20,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      BlogPostCardBadge(text: '$readTime min read'),
                      if (!isPublished) const BlogPostCardBadge(text: 'Draft'),
                    ],
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black,
                        fontSize: 12,
                      ),
                    ),
                  Row(
                    spacing: 6,
                    children: [
                      CircleAvatar(
                        radius: 18.5,
                        backgroundColor: Colors.white,
                        child: UserAvatar(
                          image: authorImageUrl != null
                              ? CachedNetworkImageProvider(
                                  getFullUrl(authorImageUrl!),
                                )
                              : null,
                          seed: authorImageSeed,
                          radius: 17.5,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authorName,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                            ),
                            if (publishedDate != null)
                              Text(
                                DateFormat.yMMMd(
                                  'en_US',
                                ).format(publishedDate!),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                              ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.push(RouteNames.blogPost(slug)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsetsDirectional.only(
                            start: 12,
                            end: 10,
                            top: 4,
                            bottom: 4,
                          ),
                          minimumSize: const Size(100, 42),
                        ),
                        label: const Text(
                          'Read more',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                        ),
                        iconAlignment: IconAlignment.end,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
