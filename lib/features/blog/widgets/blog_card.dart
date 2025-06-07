import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

class BlogPostCard extends StatelessWidget {
  const BlogPostCard({
    required this.title,
    required this.authorName,
    required this.authorImageUrl,
    required this.authorImageSeed,
    required this.publishedDate,
    required this.image,
    super.key,
  });

  final String title;
  final String authorName;
  final String? authorImageUrl;
  final String authorImageSeed;
  final DateTime publishedDate;
  final String image;

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat.yMMMd(
      'en_US',
    ); // Format date to 'MMM dd, yyyy'
    return Container(
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
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: .3),
            BlendMode.darken,
          ),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            spacing: 6,
            children: [
              UserAvatar(
                image:
                    authorImageUrl != null
                        ? CachedNetworkImageProvider(authorImageUrl!)
                        : null,
                seed: authorImageSeed,
                radius: 17.5,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authorName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    dateFormatter.format(publishedDate),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .7),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
