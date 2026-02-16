import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:totem_app/api/models/blog_post_list_schema.dart';
import 'package:totem_app/api/models/public_user_schema.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/blog/widgets/badge.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

/// Compact blog card for the home screen, matching the Figma Blogs section design.
/// Shows header image with read-time badge, title, description, author/date, and Read More.
class HomeBlogCard extends StatelessWidget {
  const HomeBlogCard({
    required this.data,
    super.key,
  });

  final BlogPostListSchema data;

  static const _borderRadius = 16.0;
  static const _imageHeight = 200.0;
  static const _contentPadding = EdgeInsets.all(16);

  @override
  Widget build(BuildContext context) {
    final slug = data.slug;
    if (slug == null || slug.isEmpty) return const SizedBox.shrink();

    return Semantics(
      button: true,
      label: 'Blog: ${data.title}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_borderRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(RouteNames.blogPost(slug)),
            borderRadius: BorderRadius.circular(_borderRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _BlogImage(
                  imageUrl: data.headerImageUrl,
                  readTime: data.readTime,
                  height: _imageHeight,
                ),
                Padding(
                  padding: _contentPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.slate,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((data.subtitle ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          data.subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.slate.withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _AuthorRow(
                              authorName: data.author?.name ?? 'Keeper',
                              author: data.author,
                              publishedDate: data.datePublished,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _ReadMoreButton(
                            onPressed: () =>
                                context.push(RouteNames.blogPost(slug)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Top image with optional "X min read" badge overlay (Figma: dark pill, top-left).
class _BlogImage extends StatelessWidget {
  const _BlogImage({
    required this.imageUrl,
    required this.readTime,
    required this.height,
  });

  final String? imageUrl;
  final int readTime;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildImage(),
          Positioned(
            top: 12,
            left: 12,
            child: BlogPostCardBadge(text: '$readTime min read'),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: getFullUrl(imageUrl!),
        fit: BoxFit.cover,
        placeholder: (_, _) => ColoredBox(
          color: Colors.grey.shade200,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (_, _, _) => const ColoredBox(
          color: AppTheme.cream,
          child: Center(
            child: Icon(Icons.article_outlined, size: 48, color: AppTheme.gray),
          ),
        ),
      );
    }
    return const ColoredBox(
      color: AppTheme.cream,
      child: Center(
        child: Icon(Icons.article_outlined, size: 48, color: AppTheme.gray),
      ),
    );
  }
}

/// Author avatar, name, and date (Figma: left side of bottom row).
class _AuthorRow extends StatelessWidget {
  const _AuthorRow({
    required this.authorName,
    required this.author,
    required this.publishedDate,
  });

  final String authorName;
  final PublicUserSchema? author;
  final DateTime? publishedDate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar.fromUserSchema(
          author,
          radius: 18,
          borderWidth: 0,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                authorName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slate,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (publishedDate != null) ...[
                const SizedBox(height: 2),
                Text(
                  DateFormat.yMMMd('en_US').format(publishedDate!),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.slate.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Pill-shaped "Read More" button (Figma: light purple bg, white text + chevron).
class _ReadMoreButton extends StatelessWidget {
  const _ReadMoreButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.mauve,
        foregroundColor: AppTheme.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Read More',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 6),
          Icon(Icons.arrow_forward_ios, size: 12),
        ],
      ),
    );
  }
}
