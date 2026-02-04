import 'package:totem_app/api/models/mobile_space_detail_schema.dart';
import 'package:totem_app/api/models/next_session_schema.dart';
import 'package:totem_app/api/models/public_user_schema.dart';
import 'package:totem_app/api/models/session_detail_schema.dart';

/// Data holder for upcoming session card display.
/// Normalizes data from different API response formats.
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
