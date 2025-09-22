import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:totem_app/api/models/blog_post_list_schema.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/assets.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

class NewBlogPostCard extends StatelessWidget {
  const NewBlogPostCard({
    required this.title,
    required this.isLarge,
    required this.subtitle,
    required this.authorName,
    required this.authorImageUrl,
    required this.authorImageSeed,
    required this.publishedDate,
    required this.image,
    required this.slug,
    required this.readTime,
    super.key,
  });

  NewBlogPostCard.fromBlogPostSchema(
    BlogPostListSchema schema, {
    super.key,
  }) : title = schema.title,
       isLarge = false,
       subtitle = schema.subtitle ?? '',
       authorName = schema.author?.name ?? 'Keeper',
       authorImageUrl = schema.author?.profileImage,
       authorImageSeed = schema.author?.profileAvatarSeed ?? '',
       publishedDate = schema.datePublished,
       slug = schema.slug!,
       image = schema.headerImageUrl,
       readTime = schema.readTime;

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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(
        start: 20,
        end: 20,
        bottom: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        image: DecorationImage(
          image: image == null || image!.isEmpty
              ? const AssetImage(TotemAssets.genericBackground)
              : CachedNetworkImageProvider(image!),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      height: 350,
      width: 350,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsetsDirectional.only(
              start: 20,
              end: 20,
              top: 20,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff262F37).withValues(alpha: .3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .2),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '$readTime min read',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),

          /// Blur effect applied to bottom content container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0xff262F37),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: .1),
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
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
                                authorImageUrl!,
                                cacheKey: slug,
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
                              color: Colors.white,
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
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                            ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.push(RouteNames.blogPost(slug));
                      },
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
        ],
      ),
    );
  }
}
