import 'package:totem_app/api/models/mobile_space_detail_schema.dart';
import 'package:totem_app/api/models/next_session_schema.dart';
import 'package:totem_app/api/models/public_user_schema.dart';
import 'package:totem_app/api/models/session_detail_schema.dart';
import 'package:totem_app/api/models/summary_spaces_schema.dart';

/// Data holder for upcoming session card display.
/// Normalizes data from different API response formats.
class UpcomingSessionData {
  /// Extracts upcoming sessions from a spaces summary.
  ///
  /// Gathers sessions from each explore space that has available events,
  /// filtering for future sessions with seats available.
  /// Sessions are sorted by start time (soonest first).
  ///
  /// [summary] - The spaces summary containing explore spaces
  /// [limit] - Maximum number of sessions to return (default: 5)
  static List<UpcomingSessionData> fromSummary(
    SummarySpacesSchema summary, {
    int limit = 5,
  }) {
    final sessions = <UpcomingSessionData>[];
    final now = DateTime.now();

    // Iterate through explore spaces and extract their next events
    for (final space in summary.explore) {
      for (final event in space.nextEvents) {
        // Only include sessions that haven't started and have seats available
        if (event.start.isAfter(now) && event.seatsLeft > 0) {
          sessions.add(UpcomingSessionData.fromSpaceAndSession(space, event));
        }
      }
    }

    // Sort by start time (soonest first)
    sessions.sort((a, b) => a.start.compareTo(b.start));

    // Return limited list
    return sessions.take(limit).toList();
  }

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
  });

  /// Creates from SessionDetailSchema (from summary.upcoming)
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
    );
  }

  /// Creates from MobileSpaceDetailSchema and NextSessionSchema
  /// (from summary.explore spaces)
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
    );
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
}
