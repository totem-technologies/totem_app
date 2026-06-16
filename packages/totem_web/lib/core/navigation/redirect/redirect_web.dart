import 'package:web/web.dart' as web;

/// Ensures the route is not blank.
///
/// The Web App is only accesible through `/room/{session_slug}`.
/// If {session_slug} is not present, redirect to the homepage with the same
/// query parameters.
///
/// Returns `true` if the route is valid, `false` otherwise.
bool ensureValidRoute() {
  final path = web.window.location.pathname;
  if (path == '/' || path == '/room' || path == '/room/') {
    final search = web.window.location.search;
    final origin = web.window.location.origin;
    web.window.location.href = '$origin/$search';
    return false;
  }
  return true;
}
