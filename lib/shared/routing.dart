import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/navigation/route_names.dart';

class RoutingUtils {
  const RoutingUtils._();

  /// Parses a URL and converts it to an app route if it's a Totem deep link.
  ///
  /// Returns the app route path if the URL is a Totem domain link, or null if
  /// it's an external link.
  static String? parseTotemDeepLink(String urlString) {
    try {
      final uri = Uri.parse(urlString);
      final host = uri.host.toLowerCase();
      final isTotemDomain =
          host == 'totem.org' ||
          host == 'www.totem.org' ||
          host == 'totem.kbl.io' ||
          host == Uri.parse(AppConfig.mobileApiUrl).host.toLowerCase();

      if (!isTotemDomain) {
        return null;
      }

      final path = uri.path;
      if (path.isEmpty || path == '/') {
        return null;
      }

      final segments = path.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) {
        return null;
      }

      final firstSegment = segments[0];

      switch (firstSegment) {
        case 'blog':
          if (segments.length >= 2) {
            return RouteNames.blogPost(segments[1]);
          }

        case 'spaces':
          if (segments.length == 2) {
            return RouteNames.space(segments[1]);
          }
          if (segments.length >= 4 &&
              segments[1].isNotEmpty &&
              segments[2] == 'event' &&
              segments[3].isNotEmpty) {
            return RouteNames.spaceSession(segments[1], segments[3]);
          }

        case 'keeper':
          if (segments.length >= 2) {
            return RouteNames.keeperProfile(segments[1]);
          }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
