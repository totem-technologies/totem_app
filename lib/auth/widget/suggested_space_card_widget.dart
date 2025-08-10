import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';

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
    final timeLabel = _buildTimeLabel(event.start);
    final title = event.title.isNotEmpty ? event.title : event.spaceTitle;
    final keeperName = event.space.author.name ?? 'Keeper';
    final seatsLeft = event.seatsLeft;

    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: backgroundImage == null
            ? null
            : DecorationImage(
                image: NetworkImage(backgroundImage),
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
                          color: const Color.fromRGBO(38, 47, 55, 0.60),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          timeLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontFamily: 'Albert Sans',
                            fontSize: 8,
                            fontStyle: FontStyle.normal,
                            fontWeight: FontWeight.w700,
                            height: 1,
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
            flex: 3,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.fromRGBO(38, 47, 55, 0),
                    Color(0xFF262F37),
                  ],
                  stops: [0.0, 1.0],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromRGBO(38, 47, 55, 0),
                      Color(0xFF262F37),
                    ],
                    stops: [0.0, 1.0],
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
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontFamily: 'Albert Sans',
                        fontSize: 14,
                        fontStyle: FontStyle.normal,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                      textAlign: TextAlign.left,
                    ),
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
                            style: const TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontFamily: 'Albert Sans',
                              fontSize: 10,
                              fontStyle: FontStyle.normal,
                              height: 1,
                            ),
                            children: [
                              const TextSpan(
                                text: 'With ',
                                style: TextStyle(fontWeight: FontWeight.w400),
                              ),
                              TextSpan(
                                text: keeperName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
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
                              child: const Text(
                                'Join',
                                style: TextStyle(
                                  color: Color(0xFFFFFFFF),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  fontFamily: 'Albert Sans',
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$seatsLeft seats left',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontFamily: 'Albert Sans',
                                fontSize: 8,
                                fontStyle: FontStyle.normal,
                                fontWeight: FontWeight.w400,
                                height: 1,
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

  String _buildTimeLabel(DateTime start) {
    final isToday =
        DateTime.now().day == start.day &&
        DateTime.now().month == start.month &&
        DateTime.now().year == start.year;
    final dateFormatter = DateFormat('E MMM dd');
    final timeFormatter = DateFormat('hh:mm a');
    if (isToday) return 'Today, ${timeFormatter.format(start)}';
    return '${dateFormatter.format(start)}, ${timeFormatter.format(start)}';
  }
}
