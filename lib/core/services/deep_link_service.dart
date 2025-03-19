import 'dart:async';
import 'package:flutter/foundation.dart';

/// Service to handle deep links and URI scheme opening.
///
/// This service handles both initial deep links (when the app is opened from a link)
/// and background deep links (when the app is already running).
class DeepLinkService {
  // Stream controller for deep links
  final StreamController<Uri> _deepLinkStreamController =
      StreamController<Uri>.broadcast();

  // Stream of deep links that can be listened to throughout the app
  Stream<Uri> get deepLinkStream => _deepLinkStreamController.stream;

  // Store the most recent deep link
  Uri? _latestDeepLink;
  Uri? get latestDeepLink => _latestDeepLink;

  // Flag to track initialization
  bool _initialized = false;

  /// Initialize the deep link service.
  ///
  /// Sets up event channels and initial listeners.
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('DeepLinkService already initialized');
      return;
    }

    try {
      debugPrint('Initializing DeepLinkService...');

      // Simulate initialization delay
      await Future.delayed(const Duration(milliseconds: 200));

      // TODO: In a real implementation, set up platform channels or
      // use a package like uni_links to handle deep links

      _initialized = true;
      debugPrint('DeepLinkService initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize DeepLinkService: $e');
      // Fail gracefully - mark as initialized anyway
      _initialized = true;
      rethrow;
    }
  }

  /// Handle the initial link that may have opened the app.
  ///
  /// This should be called once during app startup.
  Future<Uri?> handleInitialLink() async {
    if (!_initialized) {
      debugPrint('DeepLinkService not initialized. Call initialize() first.');
      return null;
    }

    try {
      // TODO: In a real implementation, get the initial link from platform channel
      // or uni_links package

      // For now, we'll just return null to indicate no deep link
      debugPrint('Checking for initial deep link: None found');
      return null;
    } catch (e) {
      debugPrint('Error handling initial deep link: $e');
      return null;
    }
  }

  /// Start listening for incoming links while the app is running.
  void handleIncomingLinks() {
    if (!_initialized) {
      debugPrint('DeepLinkService not initialized. Call initialize() first.');
      return;
    }

    debugPrint('Started listening for background deep links');

    // TODO: In a real implementation, set up a subscription to platform channels
    // or uni_links package stream of links

    // Example of how you would handle incoming links:
    /*
    _linkSubscription = uriLinkStream.listen((Uri? uri) {
      if (uri == null) return;

      _latestDeepLink = uri;
      _deepLinkStreamController.add(uri);

      debugPrint('Got deep link: $uri');
    }, onError: (Object error) {
      debugPrint('Error handling background deep link: $error');
    });
    */
  }

  /// Process a deep link URI and determine the appropriate action.
  ///
  /// Returns a map with route information that can be used for navigation.
  Map<String, dynamic> processDeepLink(Uri uri) {
    // Store the link
    _latestDeepLink = uri;

    // Example deep link parsing
    final pathSegments = uri.pathSegments;
    final queryParams = uri.queryParameters;

    // Handle magic link authentication
    if (pathSegments.isNotEmpty && pathSegments[0] == 'auth') {
      if (pathSegments.length > 1 && pathSegments[1] == 'magic-link') {
        final token = queryParams['token'];
        if (token != null) {
          debugPrint('Processing magic link authentication with token');
          return {
            'route': '/auth/magic-link',
            'params': {'token': token},
          };
        }
      }
    }

    // Handle space deep links
    if (pathSegments.isNotEmpty && pathSegments[0] == 'spaces') {
      if (pathSegments.length > 1) {
        final spaceId = pathSegments[1];
        debugPrint('Processing deep link to space: $spaceId');
        return {
          'route': '/spaces/$spaceId',
          'params': {'id': spaceId},
        };
      }
    }

    // Handle session deep links
    if (pathSegments.isNotEmpty && pathSegments[0] == 'sessions') {
      if (pathSegments.length > 1) {
        final sessionId = pathSegments[1];
        debugPrint('Processing deep link to session: $sessionId');
        return {
          'route': '/sessions/$sessionId',
          'params': {'id': sessionId},
        };
      }
    }

    // Default route info if no specific handling
    return {'route': '/', 'params': {}};
  }

  /// Clean up resources when service is no longer needed
  void dispose() {
    _deepLinkStreamController.close();

    // TODO: Clean up any platform channel subscriptions
    debugPrint('DeepLinkService disposed');
  }
}
