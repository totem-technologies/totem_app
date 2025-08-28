import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/api/models/blog_post_list_schema.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

class BlogPostCard extends StatelessWidget {
  const BlogPostCard({
    required this.title,
    required this.subtitle,
    required this.authorName,
    required this.authorImageUrl,
    required this.authorImageSeed,
    required this.publishedDate,
    required this.image,
    required this.slug,
    required this.readTime,
    this.isLarge = false,
    super.key,
  });

  BlogPostCard.fromBlogPostSchema(
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
       image = schema.headerImageUrl ?? '',
       readTime = schema.readTime;

  final String title;
  final String subtitle;
  final String authorName;
  final String? authorImageUrl;
  final String authorImageSeed;
  final DateTime? publishedDate;
  final String image;
  final String slug;
  final bool isLarge;
  final int readTime;

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat.yMMMd(
      'en_US',
    ); // Format date to 'MMM dd, yyyy'
    return InkWell(
      splashColor: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        context.push(RouteNames.blogPost(slug));
      },
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          image: DecorationImage(
            image: CachedNetworkImageProvider(image),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black45],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 10,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x99262F37),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$readTime min read',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isLarge ? 24 : 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: isLarge ? 2 : 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              Row(
                spacing: 6,
                children: [
                  UserAvatar(
                    image: authorImageUrl != null
                        ? CachedNetworkImageProvider(
                            authorImageUrl!,
                            cacheKey: slug,
                          )
                        : null,
                    seed: authorImageSeed,
                    radius: 17.5,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                        ),
                        if (publishedDate != null)
                          Text(
                            dateFormatter.format(publishedDate!),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .7),
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                          ),
                      ],
                    ),
                  ),
                  if (isLarge)
                    IgnorePointer(
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsetsDirectional.only(
                              start: 12,
                              end: 4,
                              top: 4,
                              bottom: 4,
                            ),
                            minimumSize: const Size(100, 42),
                          ),
                          label: const Text(
                            'Read',
                            style: TextStyle(fontSize: 14),
                          ),
                          icon: const Icon(Icons.arrow_forward_ios, size: 16),
                          iconAlignment: IconAlignment.end,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
