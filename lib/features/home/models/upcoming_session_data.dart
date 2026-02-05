import 'package:totem_app/api/models/mobile_space_detail_schema.dart';
import 'package:totem_app/api/models/next_session_schema.dart';
import 'package:totem_app/api/models/public_user_schema.dart';
import 'package:totem_app/api/models/session_detail_schema.dart';
import 'package:totem_app/api/models/summary_spaces_schema.dart';

/// Data holder for upcoming session card display.
class UpcomingSessionData {
  const UpcomingSessionData({
    required this.sessionSlug,
    required this.sessionTitle,
    required this.spaceSlug,
    required this.spaceTitle,
    required this.category,
    required this.imageUrl,
    required this.author,
    required this.start,
    required this.seatsLeft,
    required this.attending,
  });

  factory UpcomingSessionData.fromSpaceAndSession(
    MobileSpaceDetailSchema space,
    NextSessionSchema session,
  ) {
    return UpcomingSessionData(
      sessionSlug: session.slug,
      sessionTitle: session.title ?? space.title,
      spaceSlug: space.slug,
      spaceTitle: space.title,
      category: space.category,
      imageUrl: space.imageLink,
      author: space.author,
      start: session.start,
      seatsLeft: session.seatsLeft,
      attending: session.attending,
    );
  }

  factory UpcomingSessionData.fromSessionDetail(SessionDetailSchema session) {
    return UpcomingSessionData(
      sessionSlug: session.slug,
      sessionTitle: session.title,
      spaceSlug: session.space.slug,
      spaceTitle: session.space.title,
      category: session.space.category,
      imageUrl: session.space.imageLink,
      author: session.space.author,
      start: session.start,
      seatsLeft: session.seatsLeft,
      attending: session.attending,
    );
  }

  /// Extracts upcoming sessions from a spaces summary, sorted by start time.
  static List<UpcomingSessionData> fromSummary(
    SummarySpacesSchema summary, {
    int limit = 5,
  }) {
    final sessions = <UpcomingSessionData>[];
    final now = DateTime.now();

    for (final space in summary.explore) {
      for (final event in space.nextEvents) {
        if (event.start.isAfter(now) && event.seatsLeft > 0) {
          sessions.add(UpcomingSessionData.fromSpaceAndSession(space, event));
        }
      }
    }

    sessions.sort((a, b) => a.start.compareTo(b.start));
    return sessions.take(limit).toList();
  }

  final String sessionSlug;
  final String sessionTitle;
  final String spaceSlug;
  final String spaceTitle;
  final String? category;
  final String? imageUrl;
  final PublicUserSchema author;
  final DateTime start;
  final int seatsLeft;
  final bool attending;
}
