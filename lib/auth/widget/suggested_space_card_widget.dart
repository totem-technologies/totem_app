import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/shared/assets.dart';
import 'package:totem_app/shared/date.dart';

/// Card used in Suggestions tab, built from EventDetailSchema.
class SuggestedSpaceCard extends StatelessWidget {
  const SuggestedSpaceCard({
    required this.event,
    super.key,
  });

  final EventDetailSchema event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundImage = event.space.image;
    final timeLabel = buildTimeLabel(event.start);
    final title = event.title.isNotEmpty ? event.title : event.spaceTitle;
    final keeperName = event.space.author.name ?? 'Keeper';
    final seatsLeft = event.seatsLeft;

    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.25),
            blurRadius: 4,
            offset: Offset(0, 4),
          ),
        ],
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: backgroundImage != null
              ? CachedNetworkImageProvider(backgroundImage)
              : const AssetImage(TotemAssets.genericBackground),
          fit: BoxFit.cover,
        ),
        color: backgroundImage == null
            ? theme.colorScheme.primaryContainer
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: IntrinsicWidth(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.slate.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          timeLabel,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.slate.withValues(alpha: 0),
                    AppTheme.slate,
                  ],
                  stops: const [0, 1],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.slate.withValues(alpha: 0),
                      AppTheme.slate,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.white,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          height: 25,
                          width: 25,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: ClipOval(
                            child: () {
                              final profileImage =
                                  event.space.author.profileImage;
                              if (profileImage != null &&
                                  profileImage.isNotEmpty) {
                                return CachedNetworkImage(
                                  imageUrl: profileImage,
                                  fit: BoxFit.cover,
                                  width: 25,
                                  height: 25,
                                  placeholder: (_, _) => const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 25,
                                  ),
                                  errorWidget: (_, _, _) => Container(
                                    color: theme.colorScheme.primary,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                );
                              }
                              return Container(
                                color: theme.colorScheme.primary,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              );
                            }(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        RichText(
                          text: TextSpan(
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.white,
                              fontWeight: FontWeight.w400,
                              height: 1,
                              fontSize: 10,
                            ),
                            children: [
                              TextSpan(
                                text: 'with ',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.white,
                                ),
                              ),
                              TextSpan(
                                text: keeperName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(8, 3, 9, 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF987AA5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Join',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$seatsLeft seats left',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.white,
                                fontWeight: FontWeight.w400,
                                height: 1,
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
