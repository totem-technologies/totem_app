import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:totem_app/api/models/blog_post_schema.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

class BlogDetailAppBar extends StatelessWidget {
  const BlogDetailAppBar({required this.event, super.key});

  final BlogPostSchema event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 180),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(25),
              ),
              child: CachedNetworkImage(
                imageUrl: event.headerImageUrl!,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const Icon(Icons.error),
                color: Colors.black38,
                colorBlendMode: BlendMode.darken,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 8,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        event.title,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                          ),
                          children: <TextSpan>[
                            const TextSpan(text: 'with '),
                            TextSpan(
                              text: event.author?.name ?? 'Unknown Author',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                UserAvatar(
                  seed: event.author?.profileAvatarSeed,
                  image:
                      event.author?.profileImage != null
                          ? CachedNetworkImageProvider(
                            getFullUrl(event.author!.profileImage!),
                          )
                          : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
